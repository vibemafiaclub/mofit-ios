const request = require('supertest');
const jwt = require('jsonwebtoken');
const app = require('../index');
const { supabase, cleanup } = require('./setup');

describe('Auth API', () => {
  beforeAll(async () => {
    await cleanup();
  });

  afterAll(async () => {
    await cleanup();
  });

  const testEmail = `auth-test-${Date.now()}@test.com`;
  const testPassword = 'password123';
  let authToken;

  describe('POST /auth/signup', () => {
    it('should successfully signup with valid email and password', async () => {
      const res = await request(app)
        .post('/auth/signup')
        .send({ email: testEmail, password: testPassword });

      expect(res.status).toBe(201);
      expect(res.body).toHaveProperty('token');
      expect(res.body).toHaveProperty('user');
      expect(res.body.user.email).toBe(testEmail);
      expect(res.body.user).toHaveProperty('id');

      // Verify JWT is valid
      const decoded = jwt.verify(res.body.token, process.env.JWT_SECRET);
      expect(decoded.email).toBe(testEmail);

      authToken = res.body.token;
    });

    it('should fail with duplicate email (409)', async () => {
      const res = await request(app)
        .post('/auth/signup')
        .send({ email: testEmail, password: testPassword });

      expect(res.status).toBe(409);
      expect(res.body.error).toBe('이미 사용 중인 이메일입니다');
    });

    it('should fail with password less than 6 characters (400)', async () => {
      const res = await request(app)
        .post('/auth/signup')
        .send({ email: `short-pwd-${Date.now()}@test.com`, password: '12345' });

      expect(res.status).toBe(400);
      expect(res.body.error).toBe('비밀번호는 최소 6자 이상이어야 합니다');
    });

    it('should fail with invalid email format (400)', async () => {
      const res = await request(app)
        .post('/auth/signup')
        .send({ email: 'invalid-email', password: testPassword });

      expect(res.status).toBe(400);
      expect(res.body.error).toBe('유효한 이메일 주소를 입력해주세요');
    });
  });

  describe('POST /auth/login', () => {
    it('should successfully login with correct credentials', async () => {
      const res = await request(app)
        .post('/auth/login')
        .send({ email: testEmail, password: testPassword });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('token');
      expect(res.body).toHaveProperty('user');
      expect(res.body.user.email).toBe(testEmail);

      // Verify JWT is valid
      const decoded = jwt.verify(res.body.token, process.env.JWT_SECRET);
      expect(decoded.email).toBe(testEmail);

      authToken = res.body.token;
    });

    it('should fail with wrong password (401)', async () => {
      const res = await request(app)
        .post('/auth/login')
        .send({ email: testEmail, password: 'wrongpassword' });

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('이메일 또는 비밀번호가 올바르지 않습니다');
    });

    it('should fail with non-existent email (401)', async () => {
      const res = await request(app)
        .post('/auth/login')
        .send({ email: `nonexistent-${Date.now()}@test.com`, password: testPassword });

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('이메일 또는 비밀번호가 올바르지 않습니다');
    });
  });

  describe('JWT Verification', () => {
    // Create a protected test route for JWT verification
    const authMiddleware = require('../middleware/auth');
    const express = require('express');

    let testApp;

    beforeAll(() => {
      testApp = express();
      testApp.use(express.json());
      testApp.get('/protected', authMiddleware, (req, res) => {
        res.status(200).json({ user: req.user });
      });
    });

    it('should access protected route with valid token', async () => {
      const res = await request(testApp)
        .get('/protected')
        .set('Authorization', `Bearer ${authToken}`);

      expect(res.status).toBe(200);
      expect(res.body.user.email).toBe(testEmail);
    });

    it('should fail with invalid token (401)', async () => {
      const res = await request(testApp)
        .get('/protected')
        .set('Authorization', 'Bearer invalid-token');

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('Unauthorized');
    });

    it('should fail with no token (401)', async () => {
      const res = await request(testApp)
        .get('/protected');

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('Unauthorized');
    });

    it('should fail with malformed authorization header (401)', async () => {
      const res = await request(testApp)
        .get('/protected')
        .set('Authorization', authToken); // Missing "Bearer " prefix

      expect(res.status).toBe(401);
      expect(res.body.error).toBe('Unauthorized');
    });
  });
});
