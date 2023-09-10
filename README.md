## CgBI Stitcher

A little script to convert CgBI (Apple's proprietary PNG extension) to PNG and stitch these images together.
It was used to combine multiple CgBI tiles to one large PNG image.

The conversion is based on the PyiPNG module by venjye.
See: https://github.com/venjye/PyiPNG and https://pypi.org/project/PyiPNG/

This project converted the pixel-loops of the transformation to Cython to speed up the progress for large pictures.

## Dependencies
- Cython (or as a slower alternative PyiPNG)
- Pillow
- zlib


## How to run
1. Compile the .pyx file 

    ```python setup.py build_ext --inplace```
2. Run the script

   The script assumes that the CgBI files are in the folder `input_pics` and of the format: `PREFIX_X_Y`. 
   For a map with the top left tile `map1_0_0.png` and the lower right tile `map1_63_42.png` the command would be:
   
   `python main.py --range_x 64 --range_y 43 --prefix map1`


## Example
TODO