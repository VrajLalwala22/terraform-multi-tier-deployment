"use client";

import { useState, useRef, useEffect } from "react";

export default function Dashboard() {
  const [awsAccessKey, setAwsAccessKey] = useState("");
  const [awsSecretKey, setAwsSecretKey] = useState("");
  const [awsRegion, setAwsRegion] = useState("ap-south-1");
  const [tier, setTier] = useState("2-tier");
  const [os, setOs] = useState("ubuntu");
  const [preference, setPreference] = useState("cost");
  const [repoUrl, setRepoUrl] = useState("https://github.com/pushkar-iamops/hello-world-flask.git");
  
  const [logs, setLogs] = useState<string[]>([]);
  const [isDeploying, setIsDeploying] = useState(false);
  const logEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    logEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [logs]);

  const deploy = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!awsAccessKey || !awsSecretKey) {
      alert("Please enter AWS Credentials");
      return;
    }
    
    setIsDeploying(true);
    setLogs(["Requesting infrastructure deployment..."]);

    try {
      const res = await fetch("/api/deploy", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ awsAccessKey, awsSecretKey, awsRegion, tier, os, preference, repoUrl }),
      });

      if (!res.body) return;
      const reader = res.body.getReader();
      const decoder = new TextDecoder();

      let done = false;
      while (!done) {
        const { value, done: readerDone } = await reader.read();
        done = readerDone;
        if (value) {
          const chunk = decoder.decode(value);
          const lines = chunk.split("\n\n");
          for (const line of lines) {
            if (line.startsWith("data: ")) {
              try {
                const parsed = JSON.parse(line.substring(6));
                setLogs((prev) => [...prev, parsed.log]);
              } catch (err) {}
            }
          }
        }
      }
    } catch (err) {
      setLogs((prev) => [...prev, "Connection error occurred."]);
    }
    setIsDeploying(false);
  };

  return (
    <main className="min-h-screen p-8 bg-gradient-to-br from-gray-900 via-indigo-900 to-black text-white font-sans">
      <div className="max-w-6xl mx-auto space-y-8">
        
        <header className="text-center space-y-4">
          <h1 className="text-5xl font-extrabold tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-500">
            CloudTier Deployer
          </h1>
          <p className="text-gray-300 text-lg">Fully-Automated Terraform Infrastructure Dashboard</p>
        </header>

        <form onSubmit={deploy} className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          
          {/* Settings Panel */}
          <div className="space-y-6">
            
            {/* AWS Configuration Card */}
            <div className="bg-white/10 backdrop-blur-lg border border-white/20 p-6 rounded-2xl shadow-xl">
              <h2 className="text-2xl font-semibold mb-4 text-purple-300">AWS Configuration</h2>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Access Key ID</label>
                  <input required type="password" value={awsAccessKey} onChange={(e) => setAwsAccessKey(e.target.value)}
                    className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-purple-500 transition-colors" />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">Secret Access Key</label>
                  <input required type="password" value={awsSecretKey} onChange={(e) => setAwsSecretKey(e.target.value)}
                    className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-purple-500 transition-colors" />
                </div>
                <div>
                  <label className="block text-sm text-gray-400 mb-1">AWS Region</label>
                  <input required type="text" value={awsRegion} onChange={(e) => setAwsRegion(e.target.value)}
                    className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-purple-500 transition-colors" />
                </div>
              </div>
            </div>

            {/* Application Configuration Card */}
            <div className="bg-white/10 backdrop-blur-lg border border-white/20 p-6 rounded-2xl shadow-xl">
               <h2 className="text-2xl font-semibold mb-4 text-blue-300">Infrastructure Specs</h2>
               <div className="space-y-4">
                
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm text-gray-400 mb-1">Architecture Tier</label>
                    <select value={tier} onChange={(e) => setTier(e.target.value)} className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-blue-500 transition-colors appearance-none">
                      <option value="1-tier">1-Tier (EC2)</option>
                      <option value="2-tier">2-Tier (EC2 + RDS)</option>
                      <option value="3-tier">3-Tier (ALB + ASG + RDS)</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-sm text-gray-400 mb-1">Operating System</label>
                    <select value={os} onChange={(e) => setOs(e.target.value)} className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-blue-500 transition-colors appearance-none">
                      <option value="ubuntu">Ubuntu 22.04 LTS</option>
                      <option value="amazon">Amazon Linux 2023</option>
                    </select>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm text-gray-400 mb-1">Preference Goal</label>
                    <select value={preference} onChange={(e) => setPreference(e.target.value)} className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-blue-500 transition-colors appearance-none">
                      <option value="cost">Cost Optimized</option>
                      <option value="performance">Performance Optimized</option>
                    </select>
                  </div>
                </div>

                <div>
                  <label className="block text-sm text-gray-400 mb-1">GitHub Application URL</label>
                  <input required type="text" value={repoUrl} onChange={(e) => setRepoUrl(e.target.value)}
                    className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-blue-500 transition-colors" />
                  <p className="text-xs text-gray-500 mt-2">The web app will be auto-cloned and hosted directly on the EC2 instances.</p>
                </div>

               </div>
            </div>

            <button disabled={isDeploying} type="submit" 
              className={`w-full py-4 rounded-xl font-bold text-lg shadow-2xl transition-all duration-300 ${isDeploying ? 'bg-gray-600 text-gray-400 cursor-not-allowed' : 'bg-gradient-to-r from-blue-600 to-purple-600 hover:scale-[1.02] hover:shadow-purple-500/30 text-white'}`}>
              {isDeploying ? 'Executing Pipeline...' : 'Launch Infrastructure & Deploy'}
            </button>

          </div>

          {/* Terminal Console Panel */}
          <div className="bg-black/80 backdrop-blur-xl border border-gray-700/50 p-6 rounded-2xl shadow-2xl flex flex-col h-[700px] font-mono text-sm relative overflow-hidden">
            <div className="absolute top-0 left-0 w-full bg-gray-900/80 p-3 border-b border-gray-800 flex items-center space-x-2">
              <div className="w-3 h-3 rounded-full bg-red-500"></div>
              <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
              <div className="w-3 h-3 rounded-full bg-green-500"></div>
              <span className="ml-4 text-gray-400 tracking-wider">CloudTier Live Terminal</span>
            </div>
            
            <div className="mt-10 overflow-y-auto flex-1 space-y-1 text-green-400 whitespace-pre-wrap">
              {logs.length === 0 ? (
                <div className="text-gray-600 italic">Waiting for deployment trigger...</div>
              ) : (
                logs.map((log, i) => <div key={i}>{log}</div>)
              )}
              <div ref={logEndRef} />
            </div>
          </div>

        </form>
      </div>
    </main>
  );
}
