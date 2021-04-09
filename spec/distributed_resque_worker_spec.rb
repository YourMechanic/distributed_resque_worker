# frozen_string_literal: true

require 'webmock/rspec'
require_relative '../lib/distributed_resque_worker/resque_tester'
require_relative '../lib/distributed_resque_worker'
# rubocop:disable Metrics/BlockLength
RSpec.describe DistributedResqueWorker do
  after(:each) do
    pids = []
    Resque.workers.each do |worker|
      worker_list = worker.to_s.split(/:/)
      pids << worker_list[1]
    end
    system("kill -QUIT #{pids.join(' ')}") unless pids.empty?
    Resque.workers.each(&:unregister_worker)
    Resque.queues.each do |queue|
      Resque.remove_queue(queue) if /#{queue}/.match('ResqueTester')
    end
  end

  before(:all) do
    url = 'https://s3.amazonaws.com'
    WebMock.stub_request(:any, /#{url}/)
           .to_return(status: 200, body: '', headers: {})
  end

  after(:all) do
    FileUtils.remove_dir("#{Dir.pwd}/tmp/")
    FileUtils.mkdir_p("#{Dir.pwd}/tmp/")
  end

  it 'has a version number' do
    expect(DistributedResqueWorker::VERSION).not_to be nil
  end

  it 'should check workers are up and running' do
    `BACKGROUND=YES COUNT=1 QUEUE=* rake resque:workers`
    info = Resque.info
    expect(info[:workers]).to be(1)
  end

  it 'should enqueue with type "processor", create one file after process' do
    d = Dir.new(Dir.pwd + '/tmp')
    old_files = d.to_a.size
    worker = DistributedResqueWorker::ResqueWorker.new(
      'ResqueTester', 'development', Dir.pwd
    )

    worker.chunk_work_and_enqueue([5, 6], 'run', {})
    # [".", "..", "ResqueTester_1619096121_76660", "dev_resque.log"]
    queue = worker.instance_variable_get(:@queue)
    expect(Resque.size(queue)).to be(1)
    sleep(10)
    puts d.to_a
    expect(d.to_a.size).to be(old_files + 1)
  end

  it 'should merge the intermedial files and create a final file' do
    d = Dir.new(Dir.pwd + '/tmp')
    workname = ''
    d.to_a.each do |name|
      workname = name if name.match('ResqueTester')
    end

    new_dir = Dir.new("#{Dir.pwd}/tmp/#{workname}")
    old_files = new_dir.to_a.size
    final_tmp_file = "#{Dir.pwd}/tmp/#{workname}/#{workname}_final.csv"
    DistributedResqueWorker::ResqueWorker.merge_intermediate_files(
      workname, final_tmp_file
    )
    puts d.to_a
    puts new_dir.to_a
    # [".", "..", "ResqueTester_1619096194_47478_final.csv"]
    expect(new_dir.to_a.size).to be(old_files + 1)
  end
end
# rubocop:enable Metrics/BlockLength
