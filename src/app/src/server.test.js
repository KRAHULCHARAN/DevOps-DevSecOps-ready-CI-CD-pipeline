const request = require('supertest');
const { app, server } = require('./server');

describe('Server Endpoints', () => {
  // Close server after all tests complete
  afterAll((done) => {
    if (server) {
      server.close(done);
    } else {
      done();
    }
  });

  test('GET /health should return 200 and health status', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('healthy');
    expect(response.body).toHaveProperty('timestamp');
    expect(response.body).toHaveProperty('uptime');
  });

  test('GET /api/v1/status should return 200 and application status', async () => {
    const response = await request(app).get('/api/v1/status');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('success');
    expect(response.body).toHaveProperty('message');
    expect(response.body).toHaveProperty('features');
  });

  test('GET /api/v1/info should return 200 and application info', async () => {
    const response = await request(app).get('/api/v1/info');
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('application');
    expect(response.body).toHaveProperty('version');
    expect(response.body).toHaveProperty('technologies');
  });

  test('GET /metrics should return 200 and metrics data', async () => {
    const response = await request(app).get('/metrics');
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('http_requests_total');
    expect(response.body).toHaveProperty('http_request_duration_seconds');
  });

  test('GET /nonexistent should return 404', async () => {
    const response = await request(app).get('/nonexistent');
    expect(response.status).toBe(404);
    expect(response.body.error).toBe('Not Found');
  });
});
