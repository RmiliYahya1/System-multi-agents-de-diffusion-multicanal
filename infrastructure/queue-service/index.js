// ═══════════════════════════════════════════════════════════════
// Queue Service — Pont BullMQ ↔ n8n
// ═══════════════════════════════════════════════════════════════
//
// Ce micro-service fait le lien entre n8n et Redis BullMQ.
//
// FLUX :
//   1. n8n appelle POST /enqueue/:queueName avec un payload JSON
//   2. Le service crée un job BullMQ dans la queue demandée
//   3. BullMQ distribue le job à un Worker (dans ce même service)
//   4. Le Worker fait un POST HTTP vers le webhook n8n correspondant
//   5. n8n traite le job et retourne le résultat
//
// ENDPOINTS :
//   POST /enqueue/:queueName     — Ajouter un job dans une queue
//   POST /enqueue-batch/:queueName — Ajouter plusieurs jobs d'un coup
//   GET  /health                  — Healthcheck
//   GET  /queues                  — Dashboard Bull Board
//
// ═══════════════════════════════════════════════════════════════

const express = require('express');
const { Queue, Worker, QueueEvents } = require('bullmq');
const { createBullBoard } = require('@bull-board/api');
const { BullMQAdapter } = require('@bull-board/api/bullMQAdapter');
const { ExpressAdapter } = require('@bull-board/express');
const promClient = require('prom-client');

// ─── Configuration ──────────────────────────────────────────

const REDIS_HOST = process.env.REDIS_HOST || 'redis';
const REDIS_PORT = parseInt(process.env.REDIS_PORT || '6379');
const REDIS_PASSWORD = process.env.REDIS_PASSWORD || undefined;

const N8N_WEBHOOK_BASE = process.env.N8N_WEBHOOK_BASE_URL || 'http://dev-n8n-main.dev-app.svc.cluster.local:5678';
const PORT = parseInt(process.env.QUEUE_SERVICE_PORT || '3002');

const redisConnection = {
  host: REDIS_HOST,
  port: REDIS_PORT,
  password: REDIS_PASSWORD,
  maxRetriesPerRequest: null,
};

// ─── Définition des Queues ──────────────────────────────────

const QUEUE_CONFIGS = {
  ingestion: {
    webhookPath: '/webhook/worker-ingestion',
    concurrency: 5,
    description: 'Validation et création des jobs',
  },
  adaptation: {
    webhookPath: '/webhook/worker-adaptation',
    concurrency: 1, // Limite à 1 pour les API LLM gratuites (comme OpenRouter free)
    rateLimiter: { max: 1, duration: 3000 }, // 1 appel LLM toutes les 3 secondes max
    description: 'Adaptation du contenu via LLM',
  },
  'publication-facebook': {
    webhookPath: '/webhook/worker-publication',
    concurrency: 2,
    rateLimiter: { max: 100, duration: 3600000 }, // 100/heure
    description: 'Publication vers Facebook',
  },
  'publication-instagram': {
    webhookPath: '/webhook/worker-publication',
    concurrency: 2,
    rateLimiter: { max: 100, duration: 3600000 },
    description: 'Publication vers Instagram',
  },
  'publication-linkedin': {
    webhookPath: '/webhook/worker-publication',
    concurrency: 2,
    rateLimiter: { max: 80, duration: 86400000 }, // 80/jour
    description: 'Publication vers LinkedIn',
  },
};

// ─── Créer les Queues + Workers ─────────────────────────────

const queues = {};
const workers = {};
const circuitBreaker = {};

for (const [name, config] of Object.entries(QUEUE_CONFIGS)) {
  // Créer la queue
  const queueOpts = { connection: redisConnection };
  if (config.rateLimiter) {
    queueOpts.defaultJobOptions = {
      attempts: 3,
      backoff: { type: 'exponential', delay: 5000 },
    };
  }
  queues[name] = new Queue(name, queueOpts);

  // Créer le worker qui dispatche vers n8n
  const workerOpts = {
    connection: redisConnection,
    concurrency: config.concurrency,
  };
  if (config.rateLimiter) {
    workerOpts.limiter = config.rateLimiter;
  }

  workers[name] = new Worker(
    name,
    async (job) => {
      const webhookUrl = `${N8N_WEBHOOK_BASE}${config.webhookPath}`;
      console.log(`[${name}] Processing job ${job.id} → ${webhookUrl}`);

      const timerEnd = jobsDurationHistogram.startTimer({ 
        stage: name, 
        channel: job.data.channel || name 
      });

      try {
        const response = await fetch(webhookUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            queue_name: name,
            job_id: job.id,
            attempt: job.attemptsMade + 1,
            ...job.data,
          }),
          signal: AbortSignal.timeout(120000), // 2 minutes timeout
        });

        if (!response.ok) {
          const body = await response.text();
          throw new Error(`n8n responded ${response.status}: ${body.substring(0, 500)}`);
        }

        const result = await response.json().catch(() => ({}));
        
        // ---- Extraire les feedbacks de n8n ----
        if (result.api_platform) {
          const apiStatus = result.api_status || 'success';
          apiCallsTotalCounter.inc({ platform: result.api_platform, status: apiStatus });
          if (result.api_latency_ms) {
            apiLatencyHistogram.observe({ platform: result.api_platform }, result.api_latency_ms / 1000);
          }
        }
        if (result.llm_tokens_used) {
          const modelName = result.llm_model || 'unknown';
          llmTokensCounter.inc({ model: modelName }, result.llm_tokens_used);
        }
        // ---------------------------------------

        console.log(`[${name}] Job ${job.id} completed successfully`);
        timerEnd();
        return result;
      } catch (error) {
        console.error(`[${name}] Job ${job.id} failed: ${error.message}`);
        timerEnd();
        throw error; // BullMQ will retry based on attempts config
      }
    },
    workerOpts
  );

  // Event listeners
  workers[name].on('completed', async (job) => {
    console.log(`[${name}] ✅ Job ${job.id} completed`);
    jobsTotalCounter.inc({ 
      status: 'completed', 
      channel: job.data?.channel || name, 
      tenant: job.data?.tenant || 'default' 
    });
    // Circuit Breaker: Reset failures on success for publication queues
    if (name.startsWith('publication-')) {
      circuitBreaker[name] = 0;
    }
  });

  workers[name].on('failed', async (job, err) => {
    console.error(`[${name}] ❌ Job ${job.id} failed with error: ${err.message}`);
    jobsTotalCounter.inc({ 
      status: 'failed', 
      channel: job.data?.channel || name, 
      tenant: job.data?.tenant || 'default' 
    });
    
    // Circuit Breaker: Count consecutive failures and pause queue if threshold reached
    if (name.startsWith('publication-')) {
      circuitBreaker[name] = (circuitBreaker[name] || 0) + 1;
      const failures = circuitBreaker[name];
      console.log(`[Circuit Breaker] ${name} consecutive failures: ${failures}`);
      
      if (failures >= 5) {
        console.warn(`[Circuit Breaker] 🚨 Threshold reached for ${name}! Pausing queue for 60 seconds.`);
        await queues[name].pause();
        
        // Resume after cooldown (60s)
        setTimeout(async () => {
          console.log(`[Circuit Breaker] 🟢 Cooldown finished for ${name}. Resuming queue.`);
          circuitBreaker[name] = 0; // Reset after cooldown
          await queues[name].resume();
        }, 60000);
      }
    }
  });

  console.log(`Queue "${name}" created (concurrency: ${config.concurrency})`);
}

// ─── Bull Board (Dashboard) ────────────────────────────────

const serverAdapter = new ExpressAdapter();
serverAdapter.setBasePath('/queues');

createBullBoard({
  queues: Object.values(queues).map((q) => new BullMQAdapter(q)),
  serverAdapter,
});

// ─── Express API ───────────────────────────────────────────

const app = express();
app.use(express.json({ limit: '10mb' }));

// Dashboard
app.use('/queues', serverAdapter.getRouter());

// Healthcheck
app.get('/health', async (req, res) => {
  try {
    // Vérifier la connexion Redis via une queue
    const firstQueue = Object.values(queues)[0];
    await firstQueue.getJobCounts();
    res.json({ status: 'healthy', queues: Object.keys(queues), timestamp: new Date().toISOString() });
  } catch (error) {
    res.status(503).json({ status: 'unhealthy', error: error.message });
  }
});

// ─── Prometheus Metrics ─────────────────────────────────────
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const queueDepthGauge = new promClient.Gauge({
  name: 'diffusion_queue_depth',
  help: 'Nombre de jobs dans la file',
  labelNames: ['queue_name', 'status'],
  registers: [register],
});

const jobsTotalCounter = new promClient.Counter({
  name: 'diffusion_jobs_total',
  help: 'Total jobs créés',
  labelNames: ['status', 'channel', 'tenant'],
  registers: [register],
});

const jobsDurationHistogram = new promClient.Histogram({
  name: 'diffusion_jobs_duration_seconds',
  help: 'Durée par étape',
  labelNames: ['stage', 'channel'],
  buckets: [0.1, 0.5, 1, 2, 5, 10, 30, 60, 120, 300],
  registers: [register],
});

const apiCallsTotalCounter = new promClient.Counter({
  name: 'diffusion_api_calls_total',
  help: 'Appels API externes',
  labelNames: ['platform', 'status'],
  registers: [register],
});

const apiLatencyHistogram = new promClient.Histogram({
  name: 'diffusion_api_latency_seconds',
  help: 'Latence API',
  labelNames: ['platform'],
  buckets: [0.1, 0.2, 0.5, 1, 2, 5, 10, 30],
  registers: [register],
});

const circuitBreakerGauge = new promClient.Gauge({
  name: 'diffusion_circuit_breaker_state',
  help: 'État du circuit breaker (1=Paused, 0=Active)',
  labelNames: ['platform'],
  registers: [register],
});

const llmTokensCounter = new promClient.Counter({
  name: 'diffusion_llm_tokens_used',
  help: 'Tokens LLM consommés',
  labelNames: ['model'],
  registers: [register],
});

app.get('/metrics', async (req, res) => {
  try {
    for (const [name, queue] of Object.entries(queues)) {
      const counts = await queue.getJobCounts('waiting', 'active', 'completed', 'failed', 'delayed');
      queueDepthGauge.set({ queue_name: name, status: 'waiting' }, counts.waiting);
      queueDepthGauge.set({ queue_name: name, status: 'active' }, counts.active);
      queueDepthGauge.set({ queue_name: name, status: 'completed' }, counts.completed);
      queueDepthGauge.set({ queue_name: name, status: 'failed' }, counts.failed);
      queueDepthGauge.set({ queue_name: name, status: 'delayed' }, counts.delayed);

      const isPaused = await queue.isPaused();
      const platformLabel = name.replace('publication-', '');
      circuitBreakerGauge.set({ platform: platformLabel }, isPaused ? 1 : 0);
    }
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    res.status(500).end(error.message);
  }
});

// Enqueue un seul job
app.post('/enqueue/:queueName', async (req, res) => {
  const { queueName } = req.params;
  const queue = queues[queueName];

  if (!queue) {
    return res.status(404).json({
      error: `Queue "${queueName}" not found`,
      available: Object.keys(queues),
    });
  }

  try {
    const jobData = req.body;
    const jobOpts = {
      attempts: jobData._attempts || 3,
      backoff: { type: 'exponential', delay: jobData._delay || 5000 },
      priority: jobData._priority || 5,
      removeOnComplete: { age: 3600, count: 1000 }, // Garder 1h ou 1000 jobs
      removeOnFail: { age: 86400, count: 5000 },     // Garder 24h ou 5000 erreurs
    };

    // Delayed job (pour scheduled_at)
    if (jobData._delay_ms) {
      jobOpts.delay = jobData._delay_ms;
    }

    const job = await queue.add(queueName, jobData, jobOpts);
    console.log(`[${queueName}] Enqueued job ${job.id}`);

    jobsTotalCounter.inc({ 
      status: 'created', 
      channel: jobData.channel || queueName, 
      tenant: jobData.tenant || 'default' 
    });

    res.status(201).json({
      success: true,
      queue: queueName,
      job_id: job.id,
      enqueued_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error(`[${queueName}] Enqueue error: ${error.message}`);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Enqueue un batch de jobs
app.post('/enqueue-batch/:queueName', async (req, res) => {
  const { queueName } = req.params;
  const queue = queues[queueName];

  if (!queue) {
    return res.status(404).json({
      error: `Queue "${queueName}" not found`,
      available: Object.keys(queues),
    });
  }

  try {
    const jobs = req.body.jobs || req.body;
    if (!Array.isArray(jobs) || jobs.length === 0) {
      return res.status(400).json({ error: 'Body must contain a "jobs" array' });
    }

    const bulkJobs = jobs.map((jobData, idx) => ({
      name: queueName,
      data: jobData,
      opts: {
        attempts: jobData._attempts || 3,
        backoff: { type: 'exponential', delay: 5000 },
        priority: jobData._priority || 5,
        removeOnComplete: { age: 3600, count: 1000 },
        removeOnFail: { age: 86400, count: 5000 },
        delay: jobData._delay_ms || undefined,
      },
    }));

    const result = await queue.addBulk(bulkJobs);
    console.log(`[${queueName}] Enqueued ${result.length} jobs (batch)`);

    jobs.forEach(jobData => {
      jobsTotalCounter.inc({ 
        status: 'created', 
        channel: jobData.channel || queueName, 
        tenant: jobData.tenant || 'default' 
      });
    });

    res.status(201).json({
      success: true,
      queue: queueName,
      count: result.length,
      job_ids: result.map((j) => j.id),
      enqueued_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error(`[${queueName}] Batch enqueue error: ${error.message}`);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Stats des queues
app.get('/stats', async (req, res) => {
  const stats = {};
  for (const [name, queue] of Object.entries(queues)) {
    stats[name] = await queue.getJobCounts();
  }
  res.json({ stats, timestamp: new Date().toISOString() });
});

// ─── Démarrage ─────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`
═══════════════════════════════════════════════════════════
  Queue Service démarré
  
  API:        http://localhost:${PORT}
  Dashboard:  http://localhost:${PORT}/queues
  Health:     http://localhost:${PORT}/health
  Stats:      http://localhost:${PORT}/stats
  
  n8n target: ${N8N_WEBHOOK_BASE}
  Redis:      ${REDIS_HOST}:${REDIS_PORT}
  
  Queues actives: ${Object.keys(queues).join(', ')}
═══════════════════════════════════════════════════════════
  `);
});

// ─── Graceful Shutdown ─────────────────────────────────────

async function shutdown() {
  console.log('\nStopping workers...');
  await Promise.all(Object.values(workers).map((w) => w.close()));
  console.log('Closing queues...');
  await Promise.all(Object.values(queues).map((q) => q.close()));
  console.log('Queue service stopped.');
  process.exit(0);
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
