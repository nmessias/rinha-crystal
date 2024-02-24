FROM crystallang/crystal:latest

WORKDIR /
COPY . .

RUN shards install
RUN crystal build --release rinha.cr

CMD [ "./rinha" ]
