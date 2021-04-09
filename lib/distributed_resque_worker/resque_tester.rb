# frozen_string_literal: true

require_relative '../distributed_resque_worker'

# ResqueTester
class ResqueTester
  def self.run(bucket)
    input = (1..4).to_a
    worker = DistributedResqueWorker::ResqueWorker.new(
      'ResqueTester',
      bucket,
      Dir.pwd
    )
    worker.chunk_work_and_enqueue(input, __callee__, {})
  end

  def self.run_chunk(chunk, filename, _opts = {})
    time = chunk.first
    Resque.logger.info('start run_chunk')
    sleep(time)
    Resque.logger.info('end run_chunk')
    CSV.open(filename, 'wb') do |csv|
      csv << ['id']
    end
  end

  def self.run_post(_chunk, _filename, _opts = {})
    Resque.logger.info('start run_post')
  end
end
