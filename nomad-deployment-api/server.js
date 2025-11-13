const express = require('express');
const { exec } = require('child_process');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;
const SCRIPTS_DIR = process.env.SCRIPTS_DIR || '/home/omkumar.patel/new-nomad-config';

app.use(cors());
app.use(express.json());

// Helper to execute commands
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

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Nomad Deployment API is running',
    timestamp: new Date().toISOString(),
    scriptsDir: SCRIPTS_DIR,
    port: PORT
  });
});

// List all Nomad jobs
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
        type: job.Type,
        priority: job.Priority
      }));

    res.json({ success: true, jobs: appJobs });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch Nomad jobs', 
      details: error.error 
    });
  }
});

// Get specific job status
app.get('/nomad/job/:id', async (req, res) => {
  const { id } = req.params;

  try {
    const { stdout } = await execCommand(`nomad job status -json ${id}`);
    const job = JSON.parse(stdout);

    res.json({ success: true, job });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: `Failed to fetch job ${id}`, 
      details: error.error 
    });
  }
});

// List available branches
app.get('/branches', async (req, res) => {
  try {
    const repoDir = '/home/omkumar.patel/repos/app1';
    
    await execCommand('git fetch origin', repoDir);
    const { stdout } = await execCommand('git branch -r', repoDir);
    
    const branches = stdout.trim().split('\n')
      .map(b => b.trim().replace('origin/', ''))
      .filter(b => b && !b.includes('HEAD'));

    res.json({ success: true, branches });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch branches', 
      details: error.stdout || error.error 
    });
  }
});

// Get Caddy routes (Nomad Caddy on port 2021)
app.get('/routes', async (req, res) => {
  try {
    const { stdout } = await execCommand('curl -s http://127.0.0.1:2021/config/apps/http/servers/srv0/routes');
    const routes = JSON.parse(stdout);
    
    const formattedRoutes = routes.map((route, index) => ({
      index,
      path: route.match[0]?.path[0] || 'N/A',
      upstream: route.handle[0]?.upstreams?.[0]?.dial || 'N/A',
      type: route.handle[0]?.handler || 'reverse_proxy',
      stripPrefix: route.handle[0]?.rewrite?.strip_path_prefix || null
    }));

    res.json({ success: true, routes: formattedRoutes });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch routes', 
      details: error.error 
    });
  }
});

// Deploy a branch via Nomad
app.post('/deploy', async (req, res) => {
  const { branch } = req.body;

  if (!branch) {
    return res.status(400).json({ success: false, error: 'Branch name is required' });
  }

  if (!/^[a-zA-Z0-9_-]+$/.test(branch)) {
    return res.status(400).json({ success: false, error: 'Invalid branch name' });
  }

  try {
    console.log(`🚀 Deploying branch via Nomad: ${branch}`);
    const { stdout, stderr } = await execCommand(`bash deploy-nomad.sh ${branch}`);
    
    res.json({
      success: true,
      message: `Successfully deployed ${branch} via Nomad`,
      branch,
      output: stdout,
      warnings: stderr
    });
  } catch (error) {
    console.error(`❌ Nomad deployment failed for ${branch}:`, error);
    res.status(500).json({
      success: false,
      error: `Failed to deploy ${branch} via Nomad`,
      details: error.stdout || error.error,
      stderr: error.stderr
    });
  }
});

// Cleanup a deployment
app.delete('/cleanup/:branch', async (req, res) => {
  const { branch } = req.params;

  if (!/^[a-zA-Z0-9_-]+$/.test(branch)) {
    return res.status(400).json({ success: false, error: 'Invalid branch name' });
  }

  try {
    console.log(`🧹 Cleaning up Nomad deployment: ${branch}`);
    const { stdout, stderr } = await execCommand(`bash cleanup-nomad.sh ${branch}`);
    
    res.json({
      success: true,
      message: `Successfully cleaned up ${branch}`,
      branch,
      output: stdout,
      warnings: stderr
    });
  } catch (error) {
    console.error(`❌ Nomad cleanup failed for ${branch}:`, error);
    res.status(500).json({
      success: false,
      error: `Failed to cleanup ${branch}`,
      details: error.stdout || error.error,
      stderr: error.stderr
    });
  }
});

// Get job logs
app.get('/logs/:branch', async (req, res) => {
  const { branch } = req.params;
  const jobName = `app-${branch}`;

  try {
    // Get allocation ID
    const { stdout: allocList } = await execCommand(`nomad job allocs ${jobName}`);
    const lines = allocList.trim().split('\n');
    
    if (lines.length < 2) {
      return res.status(404).json({ 
        success: false, 
        error: 'No allocations found for this job' 
      });
    }

    const allocId = lines[1].split(/\s+/)[0];
    
    // Get logs
    const { stdout: logs } = await execCommand(`nomad alloc logs ${allocId}`);

    res.json({ 
      success: true, 
      branch,
      allocId,
      logs 
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch logs', 
      details: error.error 
    });
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully...');
  process.exit(0);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Nomad Deployment API running on http://0.0.0.0:${PORT}`);
  console.log(`📁 Scripts directory: ${SCRIPTS_DIR}`);
  console.log(`📡 Endpoints:`);
  console.log(`   GET    /health`);
  console.log(`   GET    /nomad/jobs`);
  console.log(`   GET    /nomad/job/:id`);
  console.log(`   GET    /branches`);
  console.log(`   GET    /routes`);
  console.log(`   GET    /logs/:branch`);
  console.log(`   POST   /deploy`);
  console.log(`   DELETE /cleanup/:branch`);
});
