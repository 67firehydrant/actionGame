# actionGame

Basic Next.js starter untuk project actionGame.

## Local development

```bash
npm install
npm run dev
```

Buka `http://localhost:3000`.

Untuk cek production build:

```bash
npm run build
npm run start
```

## GitHub Action: Next.js build + TryCloudflare/Tailscale test server

Repo ini sudah disiapkan template workflow GitHub Actions untuk expose server test lewat:

- Cloudflare Quick Tunnel: `docs/github-workflows/nextjs-trycloudflare.yml`
- Tailscale Serve/Funnel: `docs/github-workflows/nextjs-tailscale.yml`

Template workflow tersebut untuk:

1. install dependency Node.js,
2. build aplikasi Next.js,
3. saat dijalankan manual, start web server test,
4. expose server sementara memakai Cloudflare Quick Tunnel (`trycloudflare.com`) atau Tailscale,
5. pantau log, health check, dan error selama job berjalan.

> Catatan: GitHub Actions bukan hosting permanen. Runner GitHub-hosted punya batas waktu, jadi tunnel TryCloudflare hanya hidup selama job berjalan. Workflow ini default menjaga server hidup sekitar 330 menit dan akan otomatis berhenti setelah durasi tersebut.

### Cara pakai

1. Aktifkan workflow dengan menyalin template ke folder workflow GitHub:
   ```bash
   # Cloudflare Quick Tunnel
   ./scripts/enable-github-workflow.sh cloudflare

   # atau Tailscale Serve/Funnel
   ./scripts/enable-github-workflow.sh tailscale
   ```
2. Commit dan push dengan token/user GitHub yang punya permission `workflow`.
3. Untuk menjalankan server test online:
   - buka tab **Actions** di GitHub,
   - pilih workflow Cloudflare atau Tailscale,
   - klik **Run workflow**,
   - atur `duration_minutes`, `port`, `expose_mode`, atau command custom bila perlu,
   - buka log job atau Summary untuk melihat URL hasil expose.

### Input manual workflow

Cloudflare workflow:

- `duration_minutes`: lama tunnel hidup, default `330`, dicap maksimal `350` menit.
- `port`: port lokal server Next.js, default `3000`.
- `health_path`: path untuk health check, default `/`.
- `build_command`: override command build, contoh `pnpm build`.
- `start_command`: override command start, contoh `pnpm start -- -p 3000`.

Tailscale workflow:

- `expose_mode`: `serve` untuk akses privat tailnet, `funnel` untuk akses publik internet.
- `duration_minutes`: lama server hidup, default `330`, dicap maksimal `350` menit.
- `port`: port lokal server Next.js, default `3000`.
- `health_path`: path untuk health check, default `/`.
- `start_command`: override command start, contoh `npm run start -- -p 3000`.

Untuk Tailscale, tambahkan secret repo `TS_AUTHKEY` berisi Tailscale auth key. Jika memakai `funnel`, pastikan Funnel sudah diizinkan di tailnet Tailscale kamu.

### Monitoring error

Saat tunnel/proxy aktif, workflow akan:

- stream `next-server.log` ke log Actions,
- untuk Cloudflare juga stream `cloudflared.log`,
- melakukan health check berkala ke server lokal,
- gagal otomatis bila server Next.js mati,
- gagal otomatis bila proses tunnel/proxy bermasalah,
- upload log sebagai artifact setelah job selesai/gagal.
