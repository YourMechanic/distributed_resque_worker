# frozen_string_literal: true

require 'aws-sdk'

# AwsHelper
module AwsHelper
  module_function

  def bucket(bucket)
    @bucket = Aws::S3::Resource.new(region: "us-east-1").bucket(bucket)
  end

  def s3_store_file(name, file, opt={})
    File.open(file, 'rb') do |f|
      return s3_store(name, f, opt)
    end
  end

  def s3_store(name, content, opt={})
    run_with_retry do
      obj = s3_get_object(name, opt)
      obj.upload_file(content)
      obj.exists? ? s3_get_object_url(name, opt) : nil
    end
  end

  def run_with_retry
    maxtry = 3
    ntry = 0
    begin
      return yield
    rescue Aws::S3::Errors::RequestTimeout
      ntry += 1
      if ntry > maxtry
        Bugsnag.notify($!, extra: {http_body: $!.http_body})
        raise
      end
      print "Error: #{$!}, retrying\n"
      @bucket = nil # So that we create a new bucket
      retry
    end
  end

  def doomsday
    expiration = Time.zone.now + 20.years
    # TODO:::Update after AWS changes this limit. Will likely be a while
    # since it depends on global transition to 64-bit systems
    #
    # AWS sets 01/20/2038 as an upper limit threshold on expiration date
    # due to https://en.wikipedia.org/wiki/Year_2038_problem
    aws_max_date = Time.zone.parse('2038-01-18')
    expiration = aws_max_date if expiration > aws_max_date
    expiration
  end

  def s3_get_object_url(name, opt = {})
    obj = s3_get_object(name, opt)
    return nil unless obj && obj.exists?
    secure = opt.include?(:secure) ? opt[:secure] : true
    # Replace expire time to one week (604,800 seconds) as the maximum amount of time the
    # presigned URL is one week
    obj.presigned_url(:get, secure: secure, expires_in: 604800)
  end

  def s3_delete(name)
    run_with_retry { s3_get_object(name).delete }
  end

  def s3_get_object(name, opt = {})
    Resque.logger.info("opts =============> #{opt.inspect}")
    bucket(opt[:bucket]).object(name)
  end

  def s3_download_file(name, filename, opt = {})
    run_with_retry do
      data = s3_get_object(name, opt).read
      File.open(filename, 'wb') do |file|
        file.write(data)
      end
      nil
    end
  end

  CONTENT_TYPE_TO_EXT = {
    'audio/amr' => '.amr',
    'audio/acc' => '.mp4',
    'audio/mp4' => '.mp4',
    'audio/mpeg' => '.mp3',
    'audio/ogg' => '.ogg',
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'image/gif' => '.gif',
    'text/plain' => '.txt',
    'text/rtf' => '.rtf',
    'application/zip' => '.zip',
    'application/pdf' => '.pdf',
    'application/msword' => '.doc'
  }.freeze

  def content_type(ext)
    CONTENT_TYPE_TO_EXT.each do |ct, cext|
      return ct if ext == cext
    end
  end

  def content_ext(content_type)
    CONTENT_TYPE_TO_EXT[content_type] || ''
  end
end
