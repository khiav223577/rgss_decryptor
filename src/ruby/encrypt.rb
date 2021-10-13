require_relative 'pack_rgss/rgss_encryptor'

encryptor = RgssEncryptor.new
encryptor.add_file(File.read('../Data/Scripts.rxdata'), 'Scripts.rxdata')
encryptor.encrypt('Scripts.rgssad')
