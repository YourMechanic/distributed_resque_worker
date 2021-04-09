# frozen_string_literal: true

require 'aws-sdk'

# AwsHelper
module AwsHelper
  module_function

  def bucket(bucket)
    @bucket = AWS::S3.new.buckets[bucket]
  end

  def s3_store_file(name, file, bucket_name, opt = {})
    # Stream the content for storage
    File.open(file, 'rb') do |f|
      return s3_store(name, f, bucket_name, opt)
    end
  end

  def s3_store(name, content, bucket_name, opt = {})
    run_with_retry do
      obj = s3_get_object(name, bucket_name)
      obj.write(content, opt)
      obj.exists? ? s3_get_object_url(name, bucket_name) : nil
    end
  end

  def run_with_retry
    maxtry = 3
    ntry = 0
    begin
      yield
    rescue AWS::S3::Errors::RequestTimeout
      ntry += 1
      if ntry > maxtry
        Bugsnag.notify($ERROR_INFO, extra: { http_body: $ERROR_INFO.http_body })
        raise
      end
      print "Error: #{$ERROR_INFO}, retrying\n"
      @bucket = nil # So that we create a new bucket
      retry
    end
  end

  def doomsday
    expiration = Time.zone.now + 20.years
    # TODO: ::Update after AWS changes this limit. Will likely be a while
    # since it depends on global transition to 64-bit systems
    #
    # AWS sets 01/20/2038 as an upper limit threshold on expiration date
    # due to https://en.wikipedia.org/wiki/Year_2038_problem
    aws_max_date = Time.zone.parse('2038-01-18')
    expiration = aws_max_date if expiration > aws_max_date
    expiration
  end

  def s3_get_object_url(name, bucket_name, _opt = {})
    obj = s3_get_object(name, bucket_name)
    return nil unless obj&.exists?

    secure = true
    obj.url_for(:read, secure: secure, expires: doomsday).to_s
  end

  def s3_delete(name, bucket_name)
    run_with_retry { s3_get_object(name, bucket_name).delete }
  end

  def s3_get_object(name, bucket_name)
    bucket = bucket(bucket_name)
    bucket.objects[name]
  end

  def s3_download_file(name, filename, bucket_name)
    run_with_retry do
      data = s3_get_object(name, bucket_name).read
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
