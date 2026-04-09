const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const supabase = require('../config/db');

const router = express.Router();

// Simple email regex validation
const isValidEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

// POST /auth/signup
router.post('/signup', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate email format
    if (!email || !isValidEmail(email)) {
      return res.status(400).json({ error: '유효한 이메일 주소를 입력해주세요' });
    }

    // Validate password length
    if (!password || password.length < 6) {
      return res.status(400).json({ error: '비밀번호는 최소 6자 이상이어야 합니다' });
    }

    // Check if email already exists
    const { data: existingUser, error: lookupError } = await supabase
      .from('users')
      .select('id')
      .eq('email', email)
      .single();

    if (existingUser) {
      return res.status(409).json({ error: '이미 사용 중인 이메일입니다' });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Insert user
    const { data: newUser, error: insertError } = await supabase
      .from('users')
      .insert({ email, password_hash: passwordHash })
      .select('id, email')
      .single();

    if (insertError) {
      console.error('Insert error:', insertError);
      return res.status(500).json({ error: '회원가입에 실패했습니다' });
    }

    // Generate JWT
    const token = jwt.sign(
      { id: newUser.id, email: newUser.email },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.status(201).json({
      token,
      user: { id: newUser.id, email: newUser.email }
    });
  } catch (err) {
    console.error('Signup error:', err);
    return res.status(500).json({ error: '서버 오류가 발생했습니다' });
  }
});

// POST /auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate inputs
    if (!email || !password) {
      return res.status(400).json({ error: '이메일과 비밀번호를 입력해주세요' });
    }

    // Find user by email
    const { data: user, error: lookupError } = await supabase
      .from('users')
      .select('id, email, password_hash')
      .eq('email', email)
      .single();

    if (!user) {
      return res.status(401).json({ error: '이메일 또는 비밀번호가 올바르지 않습니다' });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);

    if (!isValidPassword) {
      return res.status(401).json({ error: '이메일 또는 비밀번호가 올바르지 않습니다' });
    }

    // Generate JWT
    const token = jwt.sign(
      { id: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.status(200).json({
      token,
      user: { id: user.id, email: user.email }
    });
  } catch (err) {
    console.error('Login error:', err);
    return res.status(500).json({ error: '서버 오류가 발생했습니다' });
  }
});

module.exports = router;
