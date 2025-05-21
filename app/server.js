// server.js
require('dotenv').config();
const express = require('express');
const AWS = require('aws-sdk');
const session = require('express-session');

// Initialize AWS SDK with region
AWS.config.update({ region: process.env.AWS_REGION });

const app = express();
const s3 = new AWS.S3();
const sts = new AWS.STS();
const lambda = new AWS.Lambda();
const port = process.env.PORT || 3001;

// Middleware
app.use(express.json());
app.use(session({
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: { secure: false }
}));

// 1. Login endpoint
app.post('/login', async (req, res) => {
  const { accessKeyId, secretAccessKey, sessionToken } = req.body;
  if (!accessKeyId || !secretAccessKey) {
    return res.status(400).json({ message: 'Missing AWS credentials' });
  }
  // Update credentials for subsequent calls
  AWS.config.update({ accessKeyId, secretAccessKey, sessionToken });
  try {
    const identity = await sts.getCallerIdentity().promise();
    const username = identity.Arn.split('/').pop();
    req.session.username = username;
    return res.json({ message: '登录成功', username });
  } catch (err) {
    return res.status(401).json({ message: 'Invalid AWS credentials' });
  }
});

// 2. Group verification middleware
app.use(async (req, res, next) => {
  const username = req.session.username;
  if (!username) {
    return res.status(401).json({ message: 'Not logged in' });
  }
  try {
    const result = await lambda.invoke({
      FunctionName: process.env.VERIFY_FN_ARN,
      Payload: JSON.stringify({ username })
    }).promise();
    req.userGroups = JSON.parse(result.Payload);
    next();
  } catch (err) {
    return res.status(403).json({ message: 'Access denied' });
  }
});

// 3. GET /list
app.get('/list', async (req, res) => {
  const params = { Bucket: process.env.S3_BUCKET, Key: 'grocery-list.json' };
  try {
    const data = await s3.getObject(params).promise();
    return res.json(JSON.parse(data.Body.toString()));
  } catch (err) {
    // If no file yet, return empty list
    if (err.code === 'NoSuchKey') {
      return res.json([]);
    }
    return res.status(500).json({ message: 'Error retrieving list' });
  }
});

// 4. POST /list (Shoppers only)
app.post('/list', async (req, res) => {
  if (!req.userGroups.is_shopper) {
    return res.status(403).json({ message: 'Requires Shopper role' });
  }
  const newItem = req.body.item;
  const params = { Bucket: process.env.S3_BUCKET, Key: 'grocery-list.json' };
  try {
    let list = [];
    try {
      const data = await s3.getObject(params).promise();
      list = JSON.parse(data.Body.toString());
    } catch (err) {
      if (err.code !== 'NoSuchKey') throw err;
    }
    list.push({ item: newItem, by: req.session.username, at: new Date().toISOString() });
    await s3.putObject({
      ...params,
      Body: JSON.stringify(list),
      ContentType: 'application/json'
    }).promise();
    return res.json({ message: 'Item added', list });
  } catch (err) {
    return res.status(500).json({ message: 'Error updating list' });
  }
});

// 5. Start server
app.listen(port, () => console.log(`Server running on port ${port}`));
