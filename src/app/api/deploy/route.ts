import { NextRequest } from "next/server";
import { spawn } from "child_process";
import fs from "fs/promises";
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
        const { awsAccessKey, awsSecretKey, awsRegion, tier, os, preference, repoUrl } = body;

        const tfVarsContent = `tier       = "${tier}"
os         = "${os}"
preference = "${preference}"
repo_url   = "${repoUrl}"
aws_region = "${awsRegion}"
`;

        const tfPath = path.resolve(process.cwd(), "terraform");

        send("Writing configuration variables...");
        await fs.writeFile(path.join(tfPath, "terraform.tfvars"), tfVarsContent);

        send("Initializing Terraform Workspace...");

        const env = {
          ...process.env,
          AWS_ACCESS_KEY_ID: awsAccessKey,
          AWS_SECRET_ACCESS_KEY: awsSecretKey,
          AWS_DEFAULT_REGION: awsRegion,
        };

        const init = spawn("terraform", ["init"], { cwd: tfPath, env });
        
        init.stdout.on("data", (data) => send(data.toString()));
        init.stderr.on("data", (data) => send(data.toString()));

        init.on("close", (code) => {
          if (code !== 0) {
            send(`[Error] Terraform init failed with code ${code}.`);
            controller.close();
            return;
          }

          send("\n=========================================\nTerraform Init Complete. Applying Infrastructure...\n=========================================\n");
          const apply = spawn("terraform", ["apply", "-auto-approve"], { cwd: tfPath, env });
          
          apply.stdout.on("data", (data) => send(data.toString()));
          apply.stderr.on("data", (data) => send(data.toString()));

          apply.on("close", (applyCode) => {
            if (applyCode === 0) {
              send("\n=========================================\nDeployment Completed Successfully! 🎉\n=========================================\n");
            } else {
              send(`\n[Error] Deployment failed with code ${applyCode}.`);
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
