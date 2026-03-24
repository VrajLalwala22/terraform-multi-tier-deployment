import { NextRequest } from "next/server";
import { spawn } from "child_process";
import path from "path";

export async function POST(req: NextRequest) {
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      function send(msg: string) {
        const data = `data: ${JSON.stringify({ log: msg })}\n\n`;
        controller.enqueue(encoder.encode(data));
      }

      try {
        const body = await req.json();
        const { awsAccessKey, awsSecretKey, awsRegion } = body;

        const tfPath = path.resolve(process.cwd(), "terraform");

        const env = {
          ...process.env,
          AWS_ACCESS_KEY_ID: awsAccessKey,
          AWS_SECRET_ACCESS_KEY: awsSecretKey,
          AWS_DEFAULT_REGION: awsRegion,
        };

        send("⚠️  Initiating DESTROY sequence...");
        send("Initializing Terraform configuration...\n");

        const init = spawn("terraform", ["init"], { cwd: tfPath, env });
        
        init.stdout.on("data", (data) => send(data.toString()));
        init.stderr.on("data", (data) => send(data.toString()));

        init.on("close", (initCode) => {
          if (initCode !== 0) {
            send(`\n[Error] Terraform initialization failed with code ${initCode}.`);
            controller.close();
            return;
          }

          send("\nRunning: terraform destroy -auto-approve\n");
          const destroy = spawn("terraform", ["destroy", "-auto-approve"], { cwd: tfPath, env });

          destroy.stdout.on("data", (data) => send(data.toString()));
          destroy.stderr.on("data", (data) => send(data.toString()));

          destroy.on("close", (code) => {
            if (code === 0) {
              send("\n=========================================");
              send("✅ All infrastructure has been destroyed successfully.");
              send("=========================================\n");
            } else {
              send(`\n[Error] Destroy failed with exit code ${code}.`);
            }
            controller.close();
          });
        });
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : String(err);
        send(`[System Error]: ${errorMessage}`);
        controller.close();
      }
    }
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream",
      "Cache-Control": "no-cache",
      "Connection": "keep-alive"
    }
  });
}
