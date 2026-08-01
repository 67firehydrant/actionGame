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

## GitHub Action: Next.js build + TryCloudflare test server

Repo ini sudah disiapkan template workflow GitHub Actions di `docs/github-workflows/nextjs-trycloudflare.yml` untuk:

1. install dependency Node.js,
2. build aplikasi Next.js,
3. saat dijalankan manual, start web server test,
4. expose server sementara memakai Cloudflare Quick Tunnel (`trycloudflare.com`),
5. pantau log, health check, dan error selama job berjalan.

> Catatan: GitHub Actions bukan hosting permanen. Runner GitHub-hosted punya batas waktu, jadi tunnel TryCloudflare hanya hidup selama job berjalan. Workflow ini default menjaga server hidup sekitar 330 menit dan akan otomatis berhenti setelah durasi tersebut.

### Cara pakai

1. Aktifkan workflow dengan menyalin template ke folder workflow GitHub:
   ```bash
   mkdir -p .github/workflows
   cp docs/github-workflows/nextjs-trycloudflare.yml .github/workflows/nextjs-trycloudflare.yml
   ```
2. Commit dan push dengan token/user GitHub yang punya permission `workflow`.
3. Untuk build biasa, workflow otomatis berjalan pada `push` dan `pull_request`.
4. Untuk menjalankan server test online:
   - buka tab **Actions** di GitHub,
   - pilih **Next.js CI + TryCloudflare Test Server**,
   - klik **Run workflow**,
   - atur `duration_minutes`, `port`, atau command custom bila perlu,
   - buka log job atau Summary untuk melihat URL `https://...trycloudflare.com`.

### Input manual workflow

- `duration_minutes`: lama tunnel hidup, default `330`, dicap maksimal `350` menit.
- `port`: port lokal server Next.js, default `3000`.
- `health_path`: path untuk health check, default `/`.
- `build_command`: override command build, contoh `pnpm build`.
- `start_command`: override command start, contoh `pnpm start -- -p 3000`.

### Monitoring error

Saat tunnel aktif, workflow akan:

- stream `next-server.log` dan `cloudflared.log` ke log Actions,
- melakukan health check berkala ke server lokal,
- gagal otomatis bila server Next.js mati,
- gagal otomatis bila proses `cloudflared` mati,
- upload log sebagai artifact `nextjs-trycloudflare-logs` setelah job selesai/gagal.
