# encoding: utf-8

require 'carrierwave/processing/mime_types'

class AttachmentUploader < CarrierWave::Uploader::Base
  include CarrierWave::MimeTypes

  process :set_content_type
  after :retrieve_from_cache, :set_content_type

  version :thumbnail do
    def full_filename(for_file)
      super + ".png"
    end
    process :generate_thumbnail, :if => :pdf?
  end

  def store_dir
    "system/uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def generate_thumbnail
    get_first_page_as_png(105,140)
  end

  def pdf?(file)
    file.content_type == "application/pdf"
  end

  def get_first_page_as_png(width, height)
    thumbnail_path = current_path + ".png"
    cmd = %{convert -resize #{width}x#{height} "#{path}[0]" "#{thumbnail_path}"}
    `#{cmd}`
    @file = CarrierWave::SanitizedFile.new(thumbnail_path)
  end

  def extension_white_list
    %w(pdf csv)
  end
end