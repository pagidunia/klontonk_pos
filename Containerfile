# Klontonk POS — server pengembangan (server.mjs) di dalam container.
# Tidak ada dependensi npm. Folder proyek dipasang ke /app oleh compose.yaml agar
# perubahan stok/harga tertulis ke js/stock.js di komputer Anda, bukan di dalam container.
FROM public.ecr.aws/docker/library/node:lts-alpine

WORKDIR /app
ENV HOST=0.0.0.0 PORT=8080
EXPOSE 8080

USER node
CMD ["node", "server.mjs"]
