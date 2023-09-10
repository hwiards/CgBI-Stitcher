from zlib import decompress, compress, crc32
from struct import unpack

"""
    This file is based on the PyiPNG module by venjyew.
    See: https://github.com/venjye/PyiPNG and https://pypi.org/project/PyiPNG/
    
    Converted the pixel-loops to Cython to speed up the progress for large pictures.
    
    -----------
    MIT License

    Copyright (c) 2022 venjyew
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
"""

cpdef bytes convert (bytes img_bytes):
    '''
    This is for turning apple cgbi png to standard png
    :param img_bytes: bytes: apple png
    :return: bytes: image;
    '''

    cdef int y, x, position, pixel
    cdef unsigned char[:] chunk_idat_data
    cdef unsigned char[:] new_data

    # 8 byte signature header which allows computer to know that it's a png
    signature_header = img_bytes[:8]
    # Everything other than signature header
    rest_of_png = img_bytes[8::]
    # Create a new png starting with the signature header (https://www.w3.org/TR/PNG-Rationale.html#R.PNG-file-signature)
    new_PNG = signature_header
    # The index of byte reading
    current_byte = 8

    # Have CgBI?
    cgbi = False
    # Save IDAT data
    IDAT_data_raw = b''
    # Save IDAT type
    IDAT_type_raw = b''
    # Current image width
    img_width = 0
    # Current image height
    img_height = 0
    # Going through every chunk in png
    while current_byte < len(img_bytes):
        # Chunk Length:     4 bytes
        # Chunk Type  :     4 bytes ASCII letters
        # Chunk Data  :     defined in 'Chunk Length' field
        # CRC         :     4 bytes
        # Reading length field (chunk length is the length of data, not the whole chunk)
        chunk_length_raw = img_bytes[current_byte:current_byte + 4]
        # Turning bytes into integer
        chunk_length = int.from_bytes(chunk_length_raw, 'big')
        current_byte = current_byte + 4
        # Reading type field
        chunk_type_raw = img_bytes[current_byte:current_byte + 4]
        # Turning bytes into string
        chunk_type = str(chunk_type_raw, encoding='ASCII')
        current_byte = current_byte + 4
        # Extracting chunk_data
        chunk_data = img_bytes[current_byte:current_byte + chunk_length]
        # Reading CRC field
        chunk_CRC = img_bytes[current_byte + chunk_length:current_byte + chunk_length + 4]
        # Removing CgBI chunk
        if chunk_type == 'CgBI':
            current_byte = current_byte + chunk_length + 4
            cgbi = True
            continue
        # Reading img width and height
        elif chunk_type == 'IHDR':
            if cgbi:
                # img_width = int.from_bytes(chunk_data[0:4], 'big')
                # img_height = int.from_bytes(chunk_data[4:8], 'big')
                img_width, img_height, bitd, colort, compm, filterm, interlacem = unpack('>IIBBBBB', chunk_data)
                if compm != 0:
                    raise Exception('invalid compression method')
                if filterm != 0:
                    raise Exception('invalid filter method')
                if colort != 6:
                    raise Exception('we only support truecolor with alpha')
                if bitd != 8:
                    raise Exception('we only support a bit depth of 8')
                if interlacem != 0:
                    raise Exception('we only support no interlacing')
            else:
                raise ValueError("CgBI chunk not found, mey be a normal PNG!")
                raise
        elif chunk_type == 'IDAT':
            # Add all chunk data.keek data complete
            IDAT_type_raw = chunk_type_raw
            IDAT_data_raw = IDAT_data_raw + chunk_data
            current_byte = current_byte + chunk_length + 4
            continue
        # Turning BGRA into RGBA
        elif chunk_type == 'IEND':

            # [B,G,R,A] -> [R,G,B,A]
            # 0 -> 2
            # 1 -> 1
            # 2 -> 0
            # 3 -> 3
            # Decompressing, see more https://iphonedev.wiki/index.php/CgBI_file_format#Differences_from_PNG
            try:
                buffer_size = img_width * img_height * 4 + img_height
                chunk_idat_data = bytearray(decompress(IDAT_data_raw, wbits=-8, bufsize=buffer_size))
            except Exception as e:
                raise ArithmeticError('Error resolving IDAT chunk!\n' + str(e))
            # Creating bytes like new data
            #new_data = b''
            new_data = bytearray(img_width * 4 * img_height + img_height)

            position = 0
            for y in range(img_height):
                # Separator
                new_data[position] = chunk_idat_data[position]
                # index of current position
                position += 1
                for x in range(img_width):
                    # index of current pixes
                    # pixel = len(new_data)
                    # Red
                    new_data[position] = chunk_idat_data[position + 2]
                    # Green
                    new_data[position +1] = chunk_idat_data[position + 1]
                    # Blue
                    new_data[position +2 ] = chunk_idat_data[position + 0]
                    # Alpha
                    new_data[position +3] = chunk_idat_data[position + 3]
                    position += 4
            chunk_idat_data2 = new_data
            chunk_idat_data2 = compress(chunk_idat_data2)
            chunk_length_raw = len(chunk_idat_data2).to_bytes(4, 'big')
            # cal new crc
            new_CRC = crc32(IDAT_type_raw)
            new_CRC = crc32(chunk_idat_data2, new_CRC)
            new_CRC = (new_CRC + 0x100000000) % 0x100000000
            new_PNG = new_PNG + chunk_length_raw + IDAT_type_raw + chunk_idat_data2 + new_CRC.to_bytes(4, 'big')

        new_CRC = crc32(chunk_type_raw)
        new_CRC = crc32(chunk_data, new_CRC)
        new_CRC = (new_CRC + 0x100000000) % 0x100000000
        new_PNG = new_PNG + chunk_length_raw + chunk_type_raw + chunk_data + new_CRC.to_bytes(4, 'big')
        current_byte = current_byte + chunk_length + 4
    return new_PNG