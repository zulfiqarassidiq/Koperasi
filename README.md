# Kasir POS Koperasi Flutter Foundation

This scaffold uses the exact Supabase tables requested:

- kategori_produk
- produk
- stok_masuk
- transaksi
- detail_transaksi
- pengeluaran

No additional database tables are introduced.

## Run

1. Copy `assets/env/.env.example` to `assets/env/.env` if needed.
2. Fill `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
3. Run `flutter pub get`.
4. Run `flutter run`.

## Architecture

- `core/`: shared config, theme, errors, table constants.
- `data/models/`: model mapping for the existing Supabase tables.
- `data/datasources/`: direct Supabase access.
- `data/repositories/`: repository boundary for Riverpod-facing data access.
- `presentation/`: feature screens.
- `services/`: Supabase initialization and providers.
- `routes/`: Go Router setup.
- `widgets/`: shared UI building blocks.
