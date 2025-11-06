# ufsm-scanlog


## Executar o scanlog em um container

```bash
docker build -t scanlog .
docker run -it --rm --workdir /opt/scan \
        -v $(pwd):/opt/scan \
        /usr/local/bin/scanlog.sh --modelo=sieweb
```