# script to run Taiwan taginfo instance
using https://github.com/kcwu/taginfo

## If you are running taginfo with FreeBSD ezjail (what I'm using):
### Build
All in one target, it does
 - create jail, init jail, install supervisord, install dependency,
 - build code, update data
 - restart server
```sh
$ make all-jail JAIL_NAME=taginfo JAIL_IP=10.100.100.1
```

copy old build/taginfo-history.db if any
```sh
$ cp $OLD/build/taginfo-history.db $NEW/build/
```

### Daily update
```sh
$ make update-jail JAIL_NAME=taginfo
```

## If you are using FreeBSD without jail (not well tested):
### Build
(optional) install and configure supervisord
```sh
$ sudo make init-supervisord
```
install dependency packages
```sh
$ sudo make depend-freebsd
```
build code & data
```sh
$ make update
```

copy old build/taginfo-history.db if any
```sh
$ cp $OLD/build/taginfo-history.db $NEW/build/
```

### Daily update
```sh
$ make update
$ sudo make restart # optional, using supervisord
```

