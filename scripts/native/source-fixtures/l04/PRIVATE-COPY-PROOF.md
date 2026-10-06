# Private copy proof for a closed WAL database

The proof reads a synthetic fixture. It does not open a user library or a simulator.

Run it from the repository root with a new output path:

```sh
python3 scripts/native/source-fixtures/l04/prove-private-closed-wal-copy.py \
  build/native-evidence/L04/fixtures/gate-a-corruption-v2 \
  build/native-evidence/L04/private-copy-proof-01
```

The script copies the fixture database and its present sidecars to a new proof folder. It checks the copied hashes. It checkpoints the private source copy, closes it, and checks for a WAL header with no sidecars. The fixture must pass schema 1, integrity, and row counts 2/1/1.

The script then copies only that complete closed main file to another new folder. It opens that private copy in read-write mode. It changes only that copy to DELETE journal mode. It validates the schema, integrity, and row counts. It closes and reopens the file in read-only mode. It checks the same data again. It records both file headers, hashes, and source hashes before and after.

The output is preliminary host evidence. It proves this SQLite copy procedure for the fixture. It does not establish app container access, imported user data, or safe production cache ownership. A production read copy must use a unique owned path. It must keep the original library path as the only write target. It must invalidate the cached read copy after a successful library write.
