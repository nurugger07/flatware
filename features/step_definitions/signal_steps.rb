def child_pids(parent_pid=Process.pid)
  `ps -o ppid -o pid`.split("\n")[1..-1].map do |l|
    l.split.map(&:to_i)
  end.inject(Hash.new([])) do |h, (ppid, pid)|
    h.tap { h[ppid] += [pid] }
  end[parent_pid]
end

When 'I start flatware' do
  @process = run('flatware').instance_variable_get(:@process)
  begin
    sleep 1
  end while child_pids(@process.pid).empty?
end

When 'I hit CTRL-C before it is done' do
  Process.kill 'INT', @process.pid
end

Then 'I am back at the prompt' do
  sleep 1
  @process.should be_exited
end

Then 'I see a summary of unfinished work' do
  assert_partial_output 'skipped', all_output
end
