FROM node:20-alpine

WORKDIR /app

# Copier les dépendances
COPY package.json ./

# Installer les dépendances
RUN npm install --production

# Copier le code
COPY index.js ./

# Port exposé
EXPOSE 3002

# Healthcheck
HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
  CMD wget -q --spider http://localhost:3002/health || exit 1

# Démarrer le service
CMD ["node", "index.js"]
