require 'digest'
require 'base64'

module MiddlemanSimpleThumbnailer
  class Image

    attr_accessor :img_path, :middleman_config, :resize_to

    def initialize(img_path, resize_to, crop=nil, app, options_hash)
      @img_path = img_path
      @resize_to = resize_to
      @crop = crop
      @middleman_config = app.config
      @app = app
      @options = options_hash
    end

    def mime_type
      image.mime_type
    end

    def resized_img_path
      img_path.gsub(image_name, resized_image_name)
    end

    def prepare_thumbnail
      unless cached_thumbnail_available?
        resize!
        save_cached_thumbnail
      end
    end

    def base64_data
      prepare_thumbnail
      Base64.strict_encode64(File.read(cached_resized_img_abs_path))
    end

    def render
      prepare_thumbnail
      File.read(cached_resized_img_abs_path)
    end


    def save!
      prepare_thumbnail
      FileUtils.copy_file(cached_resized_img_abs_path, resized_img_abs_path)
    end

    # def self.options=(options)
    #   @@options = options
    # end

    def resized_img_abs_path
      File.join(build_dir, middleman_abs_path).gsub(image_name, resized_image_name)
    end

    def middleman_resized_abs_path
      middleman_abs_path.gsub(image_name, resized_image_name)
    end

    def middleman_abs_path
      img_path.start_with?('/') ? img_path : File.join(images_dir, img_path)
    end

    def cached_resized_img_abs_path
      File.join(cache_dir, middleman_abs_path).gsub(image_name, resized_image_name).split('.').tap { |a|
        a.insert(-2, image_checksum)
      }.join('.')
    end

    private

    def resize!
      unless @already_resized
        if @crop
          w, h = resize_to.split("x").map {|size| size.to_f}
          w_original = image[:width].to_f
          h_original = image[:height].to_f

          op_resize = ''

          if w_original * h < h_original * w
            op_resize = "#{w.to_i}x"
            w_result = w
            h_result = (h_original * w / w_original)
          else
            op_resize = "x#{h.to_i}"
            w_result = (w_original * h / h_original)
            h_result = h
          end
      
          w_offset = [ ((w_result - w) / 2.0).to_i, 0 ].max
          h_offset = [ ((h_result - h) / 2.0).to_i, 0 ].max

          image.resize(op_resize)
          image.gravity(:center)
          image.crop "#{w.to_i}x#{h.to_i}+#{w_offset}+#{h_offset}!"
        else
          image.resize(resize_to)
        end
        @already_resized = true
      end
    end

    def image
      @image ||= MiniMagick::Image.open(abs_path)
    end

    def image_checksum
      @image_checksum ||= Digest::SHA2.file(abs_path).hexdigest[0..16]
    end

    def image_name
      File.basename(abs_path)
    end

    def resized_image_name
      image_name.split('.').tap { |a| a.insert(-2, resize_to) }.join('.') # add resize_to sufix
          .gsub(/[%@!<>^]/, '>' => 'gt', '<' => 'lt', '^' => 'c')         # sanitize file name
    end

    def abs_path
      File.join(source_dir, middleman_abs_path)
    end

    def cached_thumbnail_available?
      File.exist?(cached_resized_img_abs_path)
    end

    def save_cached_thumbnail
      FileUtils.mkdir_p(File.dirname(cached_resized_img_abs_path))
      image.write(cached_resized_img_abs_path)
    end

    def source_dir
      File.absolute_path(middleman_config[:source], @app.root)
    end

    def images_dir
      middleman_config[:images_dir]
    end

    def build_dir
      middleman_config[:build_dir]
    end

    def cache_dir
      File.absolute_path(@options.cache_dir, @app.root)
    end
  end
end
