class RgssEncryptor
  RGSSAD_File = Struct.new(:filename, :filename_size, :file, :file_size)

  def initialize
    @files = []
    @magic_number = 0xDEADCAFE
  end

  def add_file(file_contents, filename)
    file = RGSSAD_File.new
    file.filename = filename
    file.filename_size = filename.size
    file.file = file_contents
    file.file_size = file_contents.size
    @files.delete_if{|f| f.filename == file.filename }
    @files << file
    @files.sort!{|a, b| a.filename <=> b.filename }
  end

  def encrypt(filename)
    return if @files.empty? && !File.exist?(filename)

    rgssad = ''
    @files.each do |file|
      rgssad << [file.filename_size].pack('L')
      rgssad << file.filename

      content = file.file.force_encoding('ASCII-8BIT')
      rgssad << [content.size].pack('L')
      rgssad << content
    end

    File.open(filename, 'wb') do |file|
      file.print("RGSSAD\0\1")
      file.print(parse_rgssad(rgssad, false))
    end
  end

  def decrypt(filename)
    return unless File.exist?(filename)

    files = []
    rgssad = ''
    File.open(filename, 'rb') do |file|
      file.read(8)
      rgssad = file.read
    end
    rgssad = parse_rgssad(rgssad, true)
    offset = 0

    while rgssad[offset] != nil
      file = RGSSAD_File.new
      file.filename_size = rgssad[offset, 4].unpack('L')[0]
      offset += 4
      file.filename = rgssad[offset, file.filename_size]
      offset += file.filename_size
      file.file_size = rgssad[offset, 4].unpack('L')[0]
      offset += 4
      file.file = rgssad[offset, file.file_size]
      files << file
      offset += file.file_size
    end

    return files
  end

  private

  def next_key!
    @magic_number = (@magic_number * 7 + 3) & 0xFFFFFFFF
  end

  def parse_rgssad(string, decrypt)
    new_string = ''
    offset = 0
    remember_offsets = []
    remember_keys = []
    remember_size = []

    while string[offset] != nil
      name_size = string[offset, 4].unpack('L')[0]
      new_string << [name_size ^ @magic_number].pack('L')
      name_size ^= @magic_number if decrypt
      offset += 4
      next_key!
      filename = string[offset, name_size]
      name_size.times do |i|
        filename[i] = (filename[i].ord ^ @magic_number & 0xFF).chr
        # filename.setbyte(i, filename.getbyte(i) ^ @magic_number & 0xFF)
        next_key!
      end
      new_string << filename
      offset += name_size
      data_size = string[offset, 4].unpack('L')[0]
      new_string << [data_size ^ @magic_number].pack('L')
      data_size ^= @magic_number if decrypt
      remember_size << data_size
      offset += 4
      next_key!

      data = string[offset, data_size]
      new_string << data
      remember_offsets << offset
      remember_keys << @magic_number
      offset += data_size
    end

    remember_offsets.size.times do |i|
      offset = remember_offsets[i]
      @magic_number = remember_keys[i]
      size = remember_size[i]
      data = new_string[offset, size]
      data = data.ljust(size + (4 - size % 4)) if size % 4 != 0
      s = ''
      data.unpack('L' * (data.size / 4)).each do |j|
        s << ([j ^ @magic_number].pack('L'))
        next_key!
      end
      new_string[offset, size] = s.slice(0, size)
    end

    return new_string
  end
end
