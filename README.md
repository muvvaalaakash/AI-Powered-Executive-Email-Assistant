# AeroInbox: AI-Powered Executive Email Assistant (Microservices)

AeroInbox is a real-world, production-ready email intelligence assistant built for managers, founders, and CEOs to minimize time spent reading and replying to emails. It connects securely to Gmail, fetches unread mail, uses Google Gemini (`gemini-flash-latest`) to extract structured executive summaries, classifies priorities in bulk on sync, and drafts response options.

Decomposed into a **4-tier microservices architecture** configured to deploy on a single machine or Azure Virtual Machine via Docker Compose.

---

## Architecture Diagram

```
                 Internet
                    │
                    ▼ (Port 80)
        +-----------------------+
        |  Nginx Reverse Proxy  |
        |  (Frontend Container) |
        +-----------------------+
                    │
                    ▼ (Proxy Pass /auth or /emails)
        +-----------------------+
        |      API Service      | (Orchestrator Gateway :8000)
        +-----------------------+
          /                   \
         / (Internal HTTP)     \ (Internal HTTP)
        ▼                       ▼
+---------------+       +---------------+
| Gmail Service | :8000 |  AI Service   | :8000
+---------------+       +---------------+
        │                       │
        ▼                       ▼
   Gmail API                Gemini API
```

---

## Folder Structure

```
Ai_Assistan_Email/
├── docker-compose.yml     # Central container orchestration config
├── .env.example           # Environment template
├── services/
│   ├── frontend/          # React SPA build, served via custom Nginx config (Port 80)
│   ├── api-service/       # Gateway, OAuth handling, and route orchestrator (Internal Port 8000)
│   ├── gmail-service/     # Gmail API reading, body decoding, and extraction (Internal Port 8000)
│   └── ai-service/        # Structured email analysis using Gemini 1.5 Flash (Internal Port 8000)
```

---

## Key Features
- **Stateless OAuth 2.0 Auth**: Fully secure, token-refresh supported auth loop.
- **Bulk Priority Classification**: Automatically scans and labels all unread emails (**High**, **Medium**, **Low**) during sync, displaying badges on the dashboard list instantly.
- **Gemini Free Tier Integration**: Uses `gemini-flash-latest` (Gemini 1.5 Flash) via Google AI Studio, granting **1500 free daily requests** and avoiding low trial limits.
- **Single Public Port (Port 80)**: Only Nginx is exposed. All service-to-service routing happens inside a private Docker bridge network (`aero-net`).

---

## Prerequisites
- **Docker** and **Docker Compose (v2+)**
- **Google Cloud Platform Project** with Gmail API enabled and OAuth Web Application credentials set up.
- **Google Gemini API Key** (Get one for free from [Google AI Studio](https://aistudio.google.com/)).

---

## Local Setup & Run

1. Clone the repository:
   ```bash
   git clone <repository_url> aeroinbox
   cd aeroinbox
   ```

2. Configure your environment variables. Copy `.env.example` to `.env` and fill in the values:
   ```bash
   cp .env.example .env
   ```
   *For local Docker Compose running, keep `GOOGLE_REDIRECT_URI=http://localhost/auth/callback` and `FRONTEND_URL=http://localhost`.*

3. Build and spin up the containers:
   ```bash
   docker compose build --build-arg VITE_API_URL=""
   docker compose up -d
   ```

4. Open `http://localhost` in your browser.

---

## Azure VM Deployment

### 1. VM Sizing & Firewalls
- **Instance**: `Standard_B2s` (2 vCPUs, 4GB RAM) or `Standard_B1ms` (1 vCPU, 2GB RAM) running Ubuntu 24.04 LTS.
- **Open Ports**: Open port **80** (HTTP) and port **22** (SSH) in the Azure Network Security Group (NSG) configurations.

### 2. Install Docker & Compose on Ubuntu VM
Connect to your VM via SSH and run:
```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```
*(Log out of the SSH session and log back in for permissions to take effect)*.

### 3. Clone and Start Services
```bash
# Clone the repository
git clone <repository_url> aeroinbox
cd aeroinbox

# Configure environment
cp .env.example .env
nano .env
```
> [!IMPORTANT]
> Change the variables in `.env` to match your VM's public IP:
> - `GOOGLE_REDIRECT_URI=http://<YOUR_VM_PUBLIC_IP>/auth/callback`
> - `FRONTEND_URL=http://<YOUR_VM_PUBLIC_IP>`

Build and run:
```bash
docker compose build --build-arg VITE_API_URL=""
docker compose up -d
```
Inspect health checks using `docker compose ps`. Access the app at `http://<YOUR_VM_PUBLIC_IP>`.
