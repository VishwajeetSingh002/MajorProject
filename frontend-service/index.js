const express = require("express");
const axios = require("axios");
const client = require("prom-client");
const app = express();

const PORT = process.env.PORT || 3000;
const USER_SERVICE_URL =
  process.env.USER_SERVICE_URL || "http://user-service:8000";

// Prometheus Metrics Setup (Preserved for Observability)
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ register: client.register });

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", client.register.contentType);
  res.send(await client.register.metrics());
});

app.get("/", async (req, res) => {
  let users = [];
  try {
    const response = await axios.get(`${USER_SERVICE_URL}/users`);
    users = response.data;
  } catch (err) {
    console.error("Error fetching users:", err.message);
  }

  const userCards =
    users.length > 0
      ? users
          .map(
            (u) => `
        <div class="flex justify-between items-center p-4 bg-slate-800/40 rounded-xl border border-slate-800">
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 rounded-full bg-blue-500/20 text-blue-400 flex items-center justify-center font-bold">
              ${
                u.name
                  ? u.name
                      .split(" ")
                      .map((n) => n[0])
                      .join("")
                  : "U"
              }
            </div>
            <div>
              <div class="font-semibold text-slate-200">${u.name}</div>
              <div class="text-xs text-slate-400">${u.email}</div>
            </div>
          </div>
          <span class="text-xs bg-emerald-500/10 text-emerald-400 px-3 py-1 rounded-full border border-emerald-500/20">Active</span>
        </div>
      `,
          )
          .join("")
      : '<p class="text-slate-400 text-sm">No users retrieved from user-service.</p>';

  res.send(`
    <!DOCTYPE html>
    <html lang="en" class="dark">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Cloud Operations Dashboard</title>
      <script src="https://cdn.tailwindcss.com"></script>
    </head>
    <body class="bg-slate-950 text-slate-100 min-h-screen font-sans antialiased p-8">
      <div class="max-w-6xl mx-auto space-y-8">
        
        <header class="flex justify-between items-center bg-slate-900/60 backdrop-blur-md p-6 rounded-2xl border border-slate-800 shadow-xl">
          <div>
            <h1 class="text-3xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-emerald-400 via-teal-400 to-cyan-500">
              Microservices Cloud Portal - v2.3 Full Pipeline Demo Rsihu 🎯
            </h1>
            <p class="text-slate-400 text-sm mt-1">Kubernetes Cluster & Orchestration Environment</p>
          </div>
          <div class="flex items-center space-x-3 bg-emerald-500/10 border border-emerald-500/30 px-4 py-2 rounded-full">
            <span class="w-3 h-3 bg-emerald-500 rounded-full animate-pulse"></span>
            <span class="text-emerald-400 font-semibold text-xs uppercase tracking-wider">Cluster Healthy</span>
          </div>
        </header>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="bg-slate-900/50 backdrop-blur-md p-6 rounded-2xl border border-slate-800 shadow-lg">
            <div class="text-xs font-semibold text-blue-400 uppercase tracking-wider mb-2">Frontend Service</div>
            <div class="text-xl font-bold">Node.js / Express</div>
            <p class="text-slate-400 text-sm mt-2">Serving Glassmorphism UI & Gateway</p>
          </div>
          <div class="bg-slate-900/50 backdrop-blur-md p-6 rounded-2xl border border-slate-800 shadow-lg">
            <div class="text-xs font-semibold text-indigo-400 uppercase tracking-wider mb-2">Backend Microservice</div>
            <div class="text-xl font-bold">Python / FastAPI</div>
            <p class="text-slate-400 text-sm mt-2">REST API & Persistence Layer</p>
          </div>
          <div class="bg-slate-900/50 backdrop-blur-md p-6 rounded-2xl border border-slate-800 shadow-lg">
            <div class="text-xs font-semibold text-purple-400 uppercase tracking-wider mb-2">Observability</div>
            <div class="text-xl font-bold">Prometheus Stack</div>
            <p class="text-slate-400 text-sm mt-2">Active Probing & Metrics Collection</p>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div class="lg:col-span-2 bg-slate-900/50 backdrop-blur-md p-6 rounded-2xl border border-slate-800 shadow-lg">
            <div class="flex justify-between items-center mb-6">
              <h2 class="text-lg font-bold text-slate-200">User Microservice Records</h2>
              <button onclick="location.reload()" class="bg-blue-600 hover:bg-blue-500 text-white text-xs px-4 py-2 rounded-lg font-medium transition">
                Refresh Data
              </button>
            </div>
            <div class="space-y-3">${userCards}</div>
          </div>

          <div class="bg-slate-900/50 backdrop-blur-md p-6 rounded-2xl border border-slate-800 shadow-lg space-y-4">
            <h2 class="text-lg font-bold text-slate-200 mb-4">Quick Links</h2>
            <a href="http://localhost:9090/targets" target="_blank" class="block w-full p-4 bg-slate-800/60 hover:bg-slate-800 rounded-xl border border-slate-700 transition">
              <div class="font-semibold text-blue-400 text-sm">Prometheus Targets ↗</div>
            </a>
            <a href="http://localhost:3001" target="_blank" class="block w-full p-4 bg-slate-800/60 hover:bg-slate-800 rounded-xl border border-slate-700 transition">
              <div class="font-semibold text-purple-400 text-sm">Grafana Dashboards ↗</div>
            </a>
          </div>
        </div>

      </div>
    </body>
    </html>
  `);
});

app.listen(PORT, () => console.log(`Frontend running on port ${PORT}`));
