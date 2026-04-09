const request = require('supertest');
const app = require('../index');
const { supabase, cleanup } = require('./setup');

describe('CRUD API', () => {
  let authToken;
  let userId;
  const testEmail = `crud-test-${Date.now()}@test.com`;
  const testPassword = 'password123';

  beforeAll(async () => {
    await cleanup();

    // Signup and get token
    const res = await request(app)
      .post('/auth/signup')
      .send({ email: testEmail, password: testPassword });

    expect(res.status).toBe(201);
    authToken = res.body.token;
    userId = res.body.user.id;
  });

  afterAll(async () => {
    await cleanup();
  });

  describe('Profile API', () => {
    describe('PUT /profile', () => {
      it('should create/update profile (200)', async () => {
        const res = await request(app)
          .put('/profile')
          .set('Authorization', `Bearer ${authToken}`)
          .send({
            gender: 'male',
            height: 175,
            weight: 70,
            bodyType: 'normal',
            goal: 'strength',
            coachStyle: 'warm'
          });

        expect(res.status).toBe(200);
        expect(res.body).toHaveProperty('profile');
        expect(res.body.profile.gender).toBe('male');
        expect(res.body.profile.height).toBe(175);
        expect(res.body.profile.weight).toBe(70);
        expect(res.body.profile.body_type).toBe('normal');
        expect(res.body.profile.goal).toBe('strength');
        expect(res.body.profile.coach_style).toBe('warm');
      });
    });

    describe('GET /profile', () => {
      it('should get profile (200)', async () => {
        const res = await request(app)
          .get('/profile')
          .set('Authorization', `Bearer ${authToken}`);

        expect(res.status).toBe(200);
        expect(res.body).toHaveProperty('profile');
        expect(res.body.profile.gender).toBe('male');
      });

      it('should fail without auth (401)', async () => {
        const res = await request(app)
          .get('/profile');

        expect(res.status).toBe(401);
      });
    });
  });

  describe('Sessions API', () => {
    let sessionId;
    const sessionData = {
      exerciseType: 'squat',
      startedAt: new Date().toISOString(),
      endedAt: new Date(Date.now() + 600000).toISOString(),
      totalDuration: 600,
      repCounts: [10, 8, 6]
    };

    describe('POST /sessions', () => {
      it('should create session (201)', async () => {
        const res = await request(app)
          .post('/sessions')
          .set('Authorization', `Bearer ${authToken}`)
          .send(sessionData);

        expect(res.status).toBe(201);
        expect(res.body).toHaveProperty('session');
        expect(res.body.session).toHaveProperty('id');
        expect(res.body.session.exerciseType).toBe('squat');
        expect(res.body.session.totalDuration).toBe(600);
        expect(res.body.session.repCounts).toEqual([10, 8, 6]);

        sessionId = res.body.session.id;
      });
    });

    describe('GET /sessions', () => {
      it('should get sessions including created one (200)', async () => {
        const res = await request(app)
          .get('/sessions')
          .set('Authorization', `Bearer ${authToken}`);

        expect(res.status).toBe(200);
        expect(res.body).toHaveProperty('sessions');
        expect(Array.isArray(res.body.sessions)).toBe(true);

        const createdSession = res.body.sessions.find(s => s.id === sessionId);
        expect(createdSession).toBeDefined();
        expect(createdSession.exerciseType).toBe('squat');
      });
    });

    describe('DELETE /sessions/:id', () => {
      it('should delete session (204)', async () => {
        const res = await request(app)
          .delete(`/sessions/${sessionId}`)
          .set('Authorization', `Bearer ${authToken}`);

        expect(res.status).toBe(204);
      });

      it('should return 404 for non-existent session', async () => {
        // Try to delete the same session again
        const res = await request(app)
          .delete(`/sessions/${sessionId}`)
          .set('Authorization', `Bearer ${authToken}`);

        expect(res.status).toBe(404);
      });

      it('should return 404 when trying to delete another user session', async () => {
        // Create another user
        const otherEmail = `crud-other-${Date.now()}@test.com`;
        const signupRes = await request(app)
          .post('/auth/signup')
          .send({ email: otherEmail, password: testPassword });

        const otherToken = signupRes.body.token;

        // Create a session with the other user
        const createRes = await request(app)
          .post('/sessions')
          .set('Authorization', `Bearer ${otherToken}`)
          .send(sessionData);

        const otherSessionId = createRes.body.session.id;

        // Try to delete it with the first user's token
        const deleteRes = await request(app)
          .delete(`/sessions/${otherSessionId}`)
          .set('Authorization', `Bearer ${authToken}`);

        expect(deleteRes.status).toBe(404);

        // Clean up: delete with correct token
        await request(app)
          .delete(`/sessions/${otherSessionId}`)
          .set('Authorization', `Bearer ${otherToken}`);
      });
    });
  });

  describe('Coaching API', () => {
    describe('POST /coaching/request', () => {
      it('should call Claude API and save feedback (201)', async () => {
        const res = await request(app)
          .post('/coaching/request')
          .set('Authorization', `Bearer ${authToken}`)
          .send({
            prompt: 'Say "test" only.',
            type: 'pre'
          });

        expect(res.status).toBe(201);
        expect(res.body).toHaveProperty('feedback');
        expect(res.body.feedback).toHaveProperty('id');
        expect(res.body.feedback.type).toBe('pre');
        expect(res.body.feedback).toHaveProperty('content');
        expect(res.body.feedback.content.length).toBeGreaterThan(0);
      }, 30000); // Increase timeout for Claude API call
    });

    describe('GET /coaching', () => {
      it('should get feedbacks including created one (200)', async () => {
        const res = await request(app)
          .get('/coaching')
          .set('Authorization', `Bearer ${authToken}`);

        expect(res.status).toBe(200);
        expect(res.body).toHaveProperty('feedbacks');
        expect(Array.isArray(res.body.feedbacks)).toBe(true);
        expect(res.body.feedbacks.length).toBeGreaterThan(0);
        expect(res.body.feedbacks[0].type).toBe('pre');
      });
    });
  });
});
