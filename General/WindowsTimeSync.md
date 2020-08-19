try in an admin command prompt:

```w32tm /resync```

If it errors then run the following

```
w32tm /register

sc start W32Time

w32tm /config /update /manualpeerlist:"uk.pool.ntp.org"

w32tm /resync
```
