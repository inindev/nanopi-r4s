## linux device tree for the nanopi r4s

<br/>

**build device tree images for the nanopi r4s**
```
sh make_dtb.sh
```

<i>the build will produce the target files: rk3399-nanopi-r4s.dtb and rk3399-nanopi-r4s-enterprise.dtb</i>

<br/>

**optional: create symbolic links**
```
sh make_dtb.sh links
```

<i>convenience link to various rk3399 device tree files will be created in the project directory</i>

<br/>

**optional: clean target**
```
sh make_dtb.sh clean
```

