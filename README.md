# ufsm-scanlog


## Executar o ufsm-scanlog em um container

```bash
docker build -t ufsm-scanlog .
docker run -it --rm -v $(pwd)/config.inc:/opt/config.inc -v $(pwd)/modelo.inc:/opt/modelo.inc -v $(pwd)/chaveprivada.key:/opt/chaveprivada.key  --name=scan ufsm-scanlog bash
```