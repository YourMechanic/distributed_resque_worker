# frozen_string_literal: true

require 'distributed_resque_worker/version'
require 'csv'
require 'resque'

require_relative 'distributed_resque_worker/aws_helper'
require_relative 'distributed_resque_worker/resque_tester'

# DistributedResqueWorker
module DistributedResqueWorker
  # ResqueFailure
  module ResqueFailure
    def on_failure_logging(error, *args)
      msg = "Performing #{self} caused an exception #{error} with args #{args}."
      Resque.logger.info msg
    end
  end

  # ResqueWorker
  class ResqueWorker
    CHUNK_SIZE = 100
    extend ResqueFailure

    def initialize(queue_name, bucket, root)
      @queue = "#{queue_name}_#{Time.now.to_i}_#{Random.rand(1000000)}".to_sym
      @bucket = bucket
      @root = root
      FileUtils.mkdir_p("#{root}/tmp/#{@queue}")
    end

    def chunk_work_and_enqueue(work_list, method, opts)
      total_jobs = (work_list.length.to_f / CHUNK_SIZE).ceil
      total_jobs = 1 if total_jobs.zero?
      Resque.logger.info("total_jobs #{total_jobs}")
      ResqueWorker.resque_redis.redis.set(
        ResqueWorker.resque_worker_redis_key(@queue), total_jobs
      )
      work_list.each_slice(CHUNK_SIZE).each_with_index do |chunk, index|
        details = { work_name: @queue, chunk: chunk, index: index,
                    type: 'processor', root: @root.to_s,
                    bucket: @bucket, method: method, opts: opts }
        Resque.enqueue_to(@queue, ResqueWorker, details)
      end
    end

    def self.perform(args)
      redis_key = resque_worker_redis_key(args['work_name'])
      no_jobs = resque_redis.redis.get(redis_key)
      Resque.logger.info("No of jobs remaining => #{no_jobs}")
      if args['type'] == 'processor'
        process_chunk(args)
        if resque_redis.redis.get(redis_key).to_i.zero?
          enqueue_post_processor(args)
        end
      elsif args['type'] == 'post_processor'
        post_processing(args)
      end
    end

    class << self
      def resque_redis
        Resque.redis
      end

      def resque_worker_redis_key(work_name)
        "DistributedResqueWorker:#{work_name}"
      end

      def merge_intermediate_files(work_name, final_file)
        files = "tmp/#{work_name}/#{work_name}_*.csv"
        cmd = "awk '(NR == 1) || (FNR > 1)' #{files} > #{final_file}"
        system(`#{cmd}`)
      end

      def enqueue_post_processor(args)
        Resque.logger.info('start enqueue_post_processor')
        input = args.symbolize_keys!
        details = { type: 'post_processor', work_name: input[:work_name],
                    bucket: input[:bucket], method: input[:method],
                    root: input[:root], opts: input[:opts] }
        Resque.enqueue_to(input[:work_name], ResqueWorker, details)
        Resque.logger.info('finished enqueue_post_processor')
      end

      def process_chunk(args)
        input = args.symbolize_keys!
        method_chunk = "#{input[:method]}_chunk".to_sym
        worker_class = input[:work_name].split('_').first
        worker = worker_class.constantize
        path = "#{input[:work_name]}/#{input[:work_name]}_#{input[:index]}.csv"
        filename = "#{input[:root]}/tmp/#{path}"
        worker.send(method_chunk, input[:chunk], filename, input[:opts])
        store_to_s3_delete_local_copy(path, filename, input[:bucket])
        resque_redis.redis.decr(resque_worker_redis_key(input[:work_name]))
      end

      def store_to_s3_delete_local_copy(path, filename, bucket)
        s3_name = "resque_worker/#{path}"
        begin
          AwsHelper.s3_store_file(s3_name, filename, {bucket: bucket})
          File.delete(filename)
        rescue StandardError
          Resque.logger.error($ERROR_INFO)
          nil
        end
      end

      def post_processing(args)
        input = args.symbolize_keys!
        work_name = input[:work_name]
        root = input[:root]
        final_tmp_file = "#{root}/tmp/#{work_name}/#{work_name}_final.csv"
        Resque.logger.info("start post_processing #{input}")
        begin
          download_intermediate_files(work_name, input[:bucket], root)
          delete_intermediate_s3_files(work_name, input[:bucket])
          merge_intermediate_files(work_name, final_tmp_file)
          upload_final_file_to_s3_and_send(input, final_tmp_file)
        rescue StandardError
          Resque.logger.error($ERROR_INFO)
          nil
        end
        Resque.logger.info('finished post_processing ')
      end

      def download_intermediate_files(work_name, bucket, root)
        aws_bucket = AwsHelper.bucket(bucket)
        folder = "resque_worker/#{work_name}/"
        s3_object = aws_bucket.objects({prefix: folder})
        s3_file_names = s3_object.collect(&:key)
        s3_file_names.each do |filename|
          local_file_name = filename.split('/')
          next unless local_file_name[2]

          download_file_path = "#{root}/tmp/#{work_name}/#{local_file_name[2]}"
          Resque.logger.info("download_file_path #{download_file_path} ")
          AwsHelper.s3_download_file(filename, download_file_path, bucket)
        end
      end

      def delete_intermediate_s3_files(work_name, bucket)
        aws_bucket = AwsHelper.bucket(bucket)
        folder = "resque_worker/#{work_name}/"
        s3_object = aws_bucket.objects({prefix: folder})
        s3_file_names = s3_object.collect(&:key)
        s3_file_names.each do |item|
          AwsHelper.s3_delete(item, bucket)
        end
      end

      def upload_final_file_to_s3_and_send(input, final_tmp_file)
        work_name = input[:work_name]
        s3_name = "resque_worker/#{work_name}/#{work_name}_final.csv"
        final_file_link = AwsHelper.s3_store_file(s3_name, final_tmp_file,
                                                  {bucket: input[:bucket]})
        method_post = "#{input[:method]}_post".to_sym
        worker_class = input[:work_name].split('_').first
        worker = worker_class.constantize
        worker.send(method_post, final_file_link, input[:opts])
        clean_up(work_name, input[:root])
      end

      def clean_up(queue_name, root)
        FileUtils.remove_dir("#{root}/tmp/#{queue_name}")

        delete_queue(queue_name)
        Resque.logger.info('Cleanup Done!')
      end

      def delete_queue(queue_name)
        Resque.queues.each do |queue|
          Resque.remove_queue(queue) if queue == queue_name
        end
      end
    end
  end
end
