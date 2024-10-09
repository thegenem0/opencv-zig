# OpenCV-Zig

I just started playing around with this yesterday. Bear with me.

Build OpenCV:
```
cmake -DCMAKE_CXX_COMPILER=clang++ \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_FLAGS="-stdlib=libc++" \
      -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++" \
      -DOPENCV_GENERATE_PKGCONFIG=ON \
      -DOPENCV_EXTRA_MODULES_PATH=~/opencv-build/opencv_contrib-4.x/modules \
      -DCMAKE_INSTALL_PREFIX=/usr ..
```


## License

MIT

## Author

thegenem0

This is essentially a fork of the [zigcv](https://github.com/ryoppippi/zigcv) library.
I've just updated the build system to work with the latest OpenCV version(4.10) and Zig version(0.13).
Credits to the idea and original codebase go to [ryoppippi](https://github.com/ryoppippi/zigcv).
