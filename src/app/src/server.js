const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const winston = require('winston');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Configure logging
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: 'devops-cicd-app' },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Logging middleware
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Root route - Welcome page
app.get('/', (req, res) => {
  res.status(200).json({
    message: 'Welcome to DevOps CI/CD Pipeline Application! 🚀',
    status: 'success',
    timestamp: new Date().toISOString(),
    description: 'A comprehensive CI/CD pipeline demonstrating DevOps and DevSecOps practices',
    availableEndpoints: {
      root: 'GET / - This welcome page',
      health: 'GET /health - Health check and status',
      metrics: 'GET /metrics - Prometheus metrics',
      status: 'GET /api/v1/status - Application status and features',
      info: 'GET /api/v1/info - Application information and technologies'
    },
    quickStart: {
      healthCheck: 'http://localhost:3000/health',
      apiStatus: 'http://localhost:3000/api/v1/status',
      documentation: 'Check the README.md for full setup instructions'
    },
    technologies: [
      'Node.js', 'Express', 'Docker', 'Kubernetes',
      'Jenkins', 'GitHub Actions', 'Terraform', 'Ansible',
      'SonarQube', 'Trivy', 'Prometheus', 'Grafana'
    ]
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    version: process.env.npm_package_version || '1.0.0'
  });
});

// Metrics endpoint for Prometheus
app.get('/metrics', (req, res) => {
  const metrics = {
    http_requests_total: {
      total: req.app.locals.requestCount || 0,
      timestamp: new Date().toISOString()
    },
    http_request_duration_seconds: {
      average: req.app.locals.avgResponseTime || 0,
      timestamp: new Date().toISOString()
    }
  };
  
  res.set('Content-Type', 'application/json');
  res.json(metrics);
});

// API routes
app.get('/api/v1/status', (req, res) => {
  logger.info('Status endpoint accessed', { ip: req.ip, userAgent: req.get('User-Agent') });
  res.json({
    message: 'DevOps CI/CD Pipeline Application is running!',
    status: 'success',
    timestamp: new Date().toISOString(),
    features: [
      'Security scanning with SonarQube',
      'Container scanning with Trivy',
      'Dependency scanning with OWASP',
      'Secrets detection with Gitleaks',
      'Monitoring with Prometheus & Grafana',
      'Deployment to Kubernetes'
    ]
  });
});

app.get('/api/v1/info', (req, res) => {
  res.json({
    application: 'DevOps CI/CD Pipeline Demo',
    version: '1.0.0',
    description: 'A comprehensive CI/CD pipeline demonstrating DevOps and DevSecOps practices',
    technologies: [
      'Node.js', 'Express', 'Docker', 'Kubernetes',
      'Jenkins', 'GitHub Actions', 'Terraform', 'Ansible',
      'SonarQube', 'Trivy', 'Prometheus', 'Grafana'
    ],
    endpoints: [
      'GET /health - Health check',
      'GET /metrics - Prometheus metrics',
      'GET /api/v1/status - Application status',
      'GET /api/v1/info - Application information'
    ]
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err);
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`,
    timestamp: new Date().toISOString()
  });
});

// Request counting middleware
app.use((req, res, next) => {
  req.app.locals.requestCount = (req.app.locals.requestCount || 0) + 1;
  next();
});

// Response time middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    const avgTime = req.app.locals.avgResponseTime || 0;
    const totalRequests = req.app.locals.requestCount || 1;
    req.app.locals.avgResponseTime = (avgTime * (totalRequests - 1) + duration) / totalRequests;
  });
  next();
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
    process.exit(0);
  });
});

// Start server
const server = app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
  logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
  logger.info(`Health check: http://localhost:${PORT}/health`);
  logger.info(`Metrics: http://localhost:${PORT}/metrics`);
});

// Only start server if this is the main module (not imported for testing)
if (require.main === module) {
  // Server is already started above
} else {
  // For testing, export the server instance so it can be closed
  module.exports = { app, server };
}

// Export app for backward compatibility
module.exports.app = app;
