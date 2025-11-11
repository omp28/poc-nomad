const express = require('express');
const { exec } = require('child_process');
const cors = require('cors');

const app = express();
const PORT = 3000;
const SCRIPTS_DIR = '/home/omkumar.patel/new-nomad-config';

app.use(cors());
app.use(express.json());

const execCommand = (command, cwd = SCRIPTS_DIR) => {
  return new Promise((resolve, reject) => {
    exec(command, { cwd, maxBuffer: 1024 * 1024 * 10 }, (error, stdout, stderr) => {
      if (error) {
        reject({ error: error.message, stderr, stdout });
      } else {
        resolve({ stdout, stderr });
      }
    });
  });
};

app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Nomad Deployment API is running',
    timestamp: new Date().toISOString()
  });
});

app.get('/nomad/jobs', async (req, res) => {
  try {
    const { stdout } = await execCommand('nomad job status -json');
    const jobs = JSON.parse(stdout);
    
    const appJobs = jobs
      .filter(job => job.ID.startsWith('app-'))
      .map(job => ({
        id: job.ID,
        branch: job.ID.replace('app-', ''),
        status: job.Status,
        type: job.Type
      }));

    res.json({ success: true, jobs: appJobs });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Failed to fetch jobs', details: error.error });
  }
});

app.post('/deploy', async (req, res) => {
  const { branch } = req.body;

  if (!branch || !/^[a-zA-Z0-9_-]+$/.test(branch)) {
    return res.status(400).json({ success: false, error: 'Invalid branch name' });
  }

  try {
    console.log(`🚀 Deploying branch: ${branch}`);
    const { stdout, stderr } = await execCommand(`bash deploy-nomad.sh ${branch}`);
    
    res.json({
      success: true,
      message: `Successfully deployed ${branch}`,
      branch,
      output: stdout,
      warnings: stderr
    });
  } catch (error) {
    console.error(`❌ Deployment failed:`, error);
    res.status(500).json({
      success: false,
      error: `Failed to deploy ${branch}`,
      details: error.stdout || error.error,
      stderr: error.stderr
    });
  }
});

app.delete('/cleanup/:branch', async (req, res) => {
  const { branch } = req.params;

  if (!/^[a-zA-Z0-9_-]+$/.test(branch)) {
    return res.status(400).json({ success: false, error: 'Invalid branch name' });
  }

  try {
    console.log(`🧹 Cleaning up: ${branch}`);
    const { stdout, stderr } = await execCommand(`bash cleanup-nomad.sh ${branch}`);
    
    res.json({
      success: true,
      message: `Successfully cleaned up ${branch}`,
      branch,
      output: stdout,
      warnings: stderr
    });
  } catch (error) {
    console.error(`❌ Cleanup failed:`, error);
    res.status(500).json({
      success: false,
      error: `Failed to cleanup ${branch}`,
      details: error.stdout || error.error,
      stderr: error.stderr
    });
  }
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Nomad API running on http://0.0.0.0:${PORT}`);
  console.log(`📡 Endpoints:`);
  console.log(`   GET    /health`);
  console.log(`   GET    /nomad/jobs`);
  console.log(`   POST   /deploy`);
  console.log(`   DELETE /cleanup/:branch`);
});
