import os
import argparse
import itertools
from multiprocessing import Pool
import functools
from PIL import Image
try:
    import png_converter as pyipng
except ImportError:
    print("Could not find compiled library, try to import slower PyiPNG from PyPI")
    import pyipng

OUTPUT_PATH = "converted_pics/"


def _conv_tile(xy, prefix):
    x, y = xy
    with open(f"input_pics/{prefix}_{x}_{y}.png", "rb") as f:
        print(f"Convert Tile: {x}, {y}")
        tile = f.read()
        converted_tile = pyipng.convert(tile)
        with open(f"{OUTPUT_PATH}{prefix}_{x}_{y}.png", "wb") as g:
            g.write(converted_tile)


def convert_tiles(range_x, range_y, prefix):
    pool = Pool()
    a = range(range_x)
    b = range(range_y)

    if not os.path.exists(OUTPUT_PATH):
        os.makedirs(OUTPUT_PATH)

    conv_tile_wrapper = functools.partial(_conv_tile, prefix=prefix)
    params = list(itertools.product(a, b))
    pool.map(conv_tile_wrapper, params)


def combine_tiles(range_x, range_y, prefix):
    images = []
    # create list of lists with the tiles at the right places
    for x in range(range_x):
        column = []
        for y in range(range_y):
            pic = Image.open(f"{OUTPUT_PATH}{prefix}_{x}_{y}.png")
            column.append(pic)
        images.append(column)

    # calc width and height of the resulting image
    total_height = sum([i.size[1] for i in images[0]])
    total_width = sum([i.size[0] for i in [j[0] for j in images]])

    print(total_width, total_height)

    # create resulting image object, that has to be filled
    new_im = Image.new("RGB", (total_width, total_height))

    # insert tile at corresponding position
    x_offset, y_offset = 0, 0
    for col in images:
        for image in col:
            new_im.paste(image, (x_offset, y_offset))
            y_offset += image.size[1]
        x_offset += image.size[0]
        y_offset = 0

    new_im.save(f"{prefix}.jpg")


def main():
    global OUTPUT_PATH
    parser = argparse.ArgumentParser(description="Check command line parameters.")

    parser.add_argument(
        "--range_x",
        required=True,
        type=int,
        help="An integer representing the numnber of tiles in x direction. Tiles named from 0 .. x. Therefore this value should be x+1.",
    )
    parser.add_argument(
        "--range_y",
        required=True,
        type=int,
        help="An integer representing the numnber of tiles in y direction. Tiles named from 0 .. y. Therefore this value should be y+1.",
    )
    parser.add_argument(
        "--prefix",
        required=True,
        type=str,
        help="A string representing the prefix of the files.",
    )
    parser.add_argument(
        "--output_folder",
        required=False,
        type=str,
        help="A string representing the output folder.",
    )

    args = parser.parse_args()
    convert_tiles(args.range_x, args.range_y, args.prefix)
    combine_tiles(args.range_x, args.range_y, args.prefix)
    if args.output_folder:
        OUTPUT_PATH = OUTPUT_PATH

if __name__ == "__main__":
    main()
