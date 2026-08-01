const features = [
  'Next.js App Router siap build',
  'Server test bisa dibuka lewat TryCloudflare',
  'GitHub Actions memantau log dan health check'
];

export default function HomePage() {
  return (
    <main className="shell">
      <section className="hero">
        <p className="eyebrow">actionGame starter</p>
        <h1>Basic Next.js sudah siap.</h1>
        <p className="subtitle">
          Ini halaman awal untuk project action game. Push ke GitHub, lalu jalankan workflow
          manual untuk mendapatkan URL sementara dari TryCloudflare.
        </p>
        <div className="actions">
          <a href="https://nextjs.org/docs" target="_blank" rel="noreferrer">
            Dokumentasi Next.js
          </a>
          <span>npm run dev</span>
        </div>
      </section>

      <section className="panel" aria-labelledby="status-title">
        <h2 id="status-title">Status setup</h2>
        <ul>
          {features.map((feature) => (
            <li key={feature}>{feature}</li>
          ))}
        </ul>
      </section>
    </main>
  );
}
