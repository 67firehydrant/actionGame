import './globals.css';

export const metadata = {
  title: 'Action Game',
  description: 'Basic Next.js starter for the actionGame project'
};

export default function RootLayout({ children }) {
  return (
    <html lang="id">
      <body>{children}</body>
    </html>
  );
}
