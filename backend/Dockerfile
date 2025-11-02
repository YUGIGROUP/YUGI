# Use Node.js 18
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (including dev dependencies for Railway)
RUN npm ci

# Copy source code
COPY . .

# Expose port (Railway will set PORT dynamically)
EXPOSE 3001

# Start the application
CMD ["npm", "start"]
