"use client";

import { useState, useRef, useEffect } from "react";

type ModalProps = {
  onConfirm: () => void;
  onCancel: () => void;
};

function DestroyConfirmModal({ onConfirm, onCancel }: ModalProps) {
  const [inputValue, setInputValue] = useState("");
  const CONFIRM_WORD = "destroy";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
      <div className="bg-gray-900 border border-red-500/40 rounded-2xl shadow-2xl w-full max-w-md p-8 space-y-6 animate-fade-in">
        
        {/* Warning Icon + Header */}
        <div className="flex flex-col items-center text-center space-y-3">
          <div className="w-16 h-16 rounded-full bg-red-500/20 border-2 border-red-500/50 flex items-center justify-center">
            <svg className="w-8 h-8 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v4m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
            </svg>
          </div>
          <h2 className="text-2xl font-bold text-white">Destroy All Infrastructure?</h2>
          <p className="text-gray-400 text-sm leading-relaxed">
            This will permanently delete all AWS resources created by Terraform — including your EC2 instances, VPC, subnets, RDS databases and key pairs. <span className="text-red-400 font-semibold">This action cannot be undone.</span>
          </p>
        </div>

        {/* Confirmation Input */}
        <div className="space-y-2">
          <label className="block text-sm text-gray-400">
            Type <span className="font-mono font-bold text-red-400">destroy</span> to confirm:
          </label>
          <input
            type="text"
            autoFocus
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            placeholder="destroy"
            className="w-full bg-black/60 border border-red-500/30 rounded-lg p-3 text-white outline-none focus:border-red-500 transition-colors font-mono placeholder-gray-600"
          />
        </div>

        {/* Action Buttons */}
        <div className="flex gap-3">
          <button
            onClick={onCancel}
            className="flex-1 py-3 rounded-xl font-semibold text-gray-300 bg-gray-800 border border-gray-700 hover:bg-gray-700 transition-all"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            disabled={inputValue !== CONFIRM_WORD}
            className={`flex-1 py-3 rounded-xl font-bold transition-all duration-300 ${
              inputValue === CONFIRM_WORD
                ? "bg-gradient-to-r from-red-600 to-rose-700 text-white hover:scale-[1.02] shadow-lg shadow-red-900/40"
                : "bg-gray-700 text-gray-500 cursor-not-allowed"
            }`}
          >
            Confirm Destroy
          </button>
        </div>
      </div>
    </div>
  );
}

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
  const [isDestroying, setIsDestroying] = useState(false);
  const [showDestroyModal, setShowDestroyModal] = useState(false);
  const logEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    logEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [logs]);

  const streamResponse = async (url: string, payload: object, label: string) => {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
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
        for (const line of chunk.split("\n\n")) {
          if (line.startsWith("data: ")) {
            try {
              const parsed = JSON.parse(line.substring(6));
              setLogs((prev) => [...prev, parsed.log]);
            } catch {
              // Ignore incomplete chunks
            }
          }
        }
      }
    }
  };

  const deploy = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!awsAccessKey || !awsSecretKey) { alert("Please enter AWS Credentials"); return; }
    setIsDeploying(true);
    setLogs(["🚀 Requesting infrastructure deployment..."]);
    try {
      await streamResponse("/api/deploy", { awsAccessKey, awsSecretKey, awsRegion, tier, os, preference, repoUrl }, "deploy");
    } catch {
      setLogs((prev) => [...prev, "Connection error occurred."]);
    }
    setIsDeploying(false);
  };

  const confirmDestroy = async () => {
    setShowDestroyModal(false);
    setIsDestroying(true);
    setLogs(["💥 Initiating destroy sequence..."]);
    try {
      await streamResponse("/api/destroy", { awsAccessKey, awsSecretKey, awsRegion }, "destroy");
    } catch {
      setLogs((prev) => [...prev, "Connection error during destroy."]);
    }
    setIsDestroying(false);
  };

  const isBusy = isDeploying || isDestroying;

  return (
    <>
      {showDestroyModal && (
        <DestroyConfirmModal
          onConfirm={confirmDestroy}
          onCancel={() => setShowDestroyModal(false)}
        />
      )}

      <main className="min-h-screen p-8 bg-gradient-to-br from-gray-900 via-indigo-950 to-black text-white font-sans">
        <div className="max-w-6xl mx-auto space-y-8">

          <header className="text-center space-y-3">
            <h1 className="text-5xl font-extrabold tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-blue-400 to-purple-500">
              CloudTier Deployer
            </h1>
            <p className="text-gray-400 text-lg">Fully-Automated Terraform Infrastructure Dashboard</p>
          </header>

          <form onSubmit={deploy} className="grid grid-cols-1 lg:grid-cols-2 gap-8">

            <div className="space-y-6">

              {/* AWS Configuration Card */}
              <div className="bg-white/5 backdrop-blur-lg border border-white/10 p-6 rounded-2xl shadow-xl">
                <h2 className="text-xl font-semibold mb-4 text-purple-300 flex items-center gap-2">
                  <span className="text-purple-400">⚙️</span> AWS Configuration
                </h2>
                <div className="space-y-4">
                  <div>
                    <label className="block text-xs uppercase tracking-widest text-gray-500 mb-1">Access Key ID</label>
                    <input required type="password" value={awsAccessKey} onChange={(e) => setAwsAccessKey(e.target.value)}
                      className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-purple-500 transition-colors text-sm" />
                  </div>
                  <div>
                    <label className="block text-xs uppercase tracking-widest text-gray-500 mb-1">Secret Access Key</label>
                    <input required type="password" value={awsSecretKey} onChange={(e) => setAwsSecretKey(e.target.value)}
                      className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-purple-500 transition-colors text-sm" />
                  </div>
                  <div>
                    <label className="block text-xs uppercase tracking-widest text-gray-500 mb-1">AWS Region</label>
                    <input required type="text" value={awsRegion} onChange={(e) => setAwsRegion(e.target.value)}
                      className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-purple-500 transition-colors text-sm" />
                  </div>
                </div>
              </div>

              {/* Infrastructure Specs Card */}
              <div className="bg-white/5 backdrop-blur-lg border border-white/10 p-6 rounded-2xl shadow-xl">
                <h2 className="text-xl font-semibold mb-4 text-blue-300 flex items-center gap-2">
                  <span>🏗️</span> Infrastructure Specs
                </h2>
                <div className="space-y-4">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs uppercase tracking-widest text-gray-500 mb-1">Architecture Tier</label>
                      <select value={tier} onChange={(e) => setTier(e.target.value)}
                        className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-blue-500 transition-colors text-sm appearance-none">
                        <option value="1-tier">1-Tier (EC2 only)</option>
                        <option value="2-tier">2-Tier (EC2 + RDS)</option>
                        <option value="3-tier">3-Tier (ALB + ASG + RDS)</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-xs uppercase tracking-widest text-gray-500 mb-1">Operating System</label>
                      <select value={os} onChange={(e) => setOs(e.target.value)}
                        className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-blue-500 transition-colors text-sm appearance-none">
                        <option value="ubuntu">Ubuntu 22.04 LTS</option>
                        <option value="amazon">Amazon Linux 2023</option>
                      </select>
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs uppercase tracking-widest text-gray-500 mb-1">Preference Goal</label>
                    <div className="grid grid-cols-2 gap-3">
                      {(["cost", "performance"] as const).map((p) => (
                        <button key={p} type="button" onClick={() => setPreference(p)}
                          className={`py-2 rounded-lg text-sm font-medium border transition-all ${preference === p ? "bg-blue-600/40 border-blue-500 text-blue-200" : "bg-black/30 border-white/10 text-gray-400 hover:border-white/30"}`}>
                          {p === "cost" ? "💰 Cost Optimized" : "⚡ Performance"}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs uppercase tracking-widest text-gray-500 mb-1">GitHub Application URL</label>
                    <input required type="text" value={repoUrl} onChange={(e) => setRepoUrl(e.target.value)}
                      className="w-full bg-black/40 border border-white/10 rounded-lg p-3 outline-none focus:border-blue-500 transition-colors text-sm" />
                    <p className="text-xs text-gray-600 mt-1">App will be auto-cloned and deployed on your EC2 instance.</p>
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="space-y-3">
                <button disabled={isBusy} type="submit"
                  className={`w-full py-4 rounded-xl font-bold text-lg shadow-2xl transition-all duration-300 ${isBusy ? "bg-gray-700 text-gray-500 cursor-not-allowed" : "bg-gradient-to-r from-blue-600 to-purple-600 hover:scale-[1.02] hover:shadow-purple-600/30 text-white"}`}>
                  {isDeploying ? "⏳ Executing Deployment Pipeline..." : "🚀 Launch Infrastructure & Deploy"}
                </button>

                <button
                  type="button"
                  disabled={isBusy}
                  onClick={() => setShowDestroyModal(true)}
                  className={`w-full py-3 rounded-xl font-semibold text-sm border transition-all duration-300 ${isBusy ? "bg-gray-800 text-gray-600 border-gray-700 cursor-not-allowed" : "bg-red-950/40 text-red-400 border-red-500/30 hover:bg-red-900/40 hover:border-red-500/60 hover:scale-[1.01]"}`}>
                  🗑️ Destroy All Infrastructure
                </button>
              </div>

            </div>

            {/* Terminal Console */}
            <div className="bg-black/80 backdrop-blur-xl border border-gray-700/50 rounded-2xl shadow-2xl flex flex-col h-[720px] font-mono text-sm overflow-hidden">
              {/* Traffic Lights */}
              <div className="bg-gray-900/80 px-4 py-3 border-b border-gray-800 flex items-center space-x-2 shrink-0">
                <div className="w-3 h-3 rounded-full bg-red-500" />
                <div className="w-3 h-3 rounded-full bg-yellow-500" />
                <div className="w-3 h-3 rounded-full bg-green-500" />
                <span className="ml-4 text-gray-500 tracking-widest text-xs uppercase">CloudTier Live Terminal</span>
                {isBusy && (
                  <span className="ml-auto flex items-center gap-1.5 text-green-400 text-xs">
                    <span className="inline-block w-2 h-2 bg-green-400 rounded-full animate-pulse" />
                    Running...
                  </span>
                )}
              </div>

              <div className="flex-1 overflow-y-auto p-4 space-y-0.5 whitespace-pre-wrap">
                {logs.length === 0 ? (
                  <div className="text-gray-600 italic text-xs mt-2">Waiting for deployment trigger...</div>
                ) : (
                  logs.map((log, i) => (
                    <div key={i} className={`leading-relaxed ${log.includes("Error") || log.includes("failed") ? "text-red-400" : log.includes("✅") || log.includes("Complete") || log.includes("successfully") ? "text-green-400" : log.includes("⚠️") || log.includes("💥") ? "text-yellow-400" : "text-gray-300"}`}>
                      {log}
                    </div>
                  ))
                )}
                <div ref={logEndRef} />
              </div>
            </div>

          </form>
        </div>
      </main>
    </>
  );
}
