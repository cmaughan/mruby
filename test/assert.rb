$ok_test = 0
$ko_test = 0
$kill_test = 0
$skip_test = 0
$asserts  = []
$test_start = Time.now if Object.const_defined?(:Time)

# Implementation of print due to the reason that there might be no print
def t_print(*args)
  i = 0
  len = args.size
  while i < len
    str = args[i].to_s
    __t_printstr__ str rescue print str
    i += 1
  end
end

##
# Create the assertion in a readable way
def assertion_string(err, str, iso=nil, e=nil, bt=nil)
  msg = "#{err}#{str}"
  msg += " [#{iso}]" if iso && !iso.empty?
  msg += " => #{e}" if e && !e.to_s.empty?
  msg += " (#{GEMNAME == 'mruby-test' ? 'core' : "mrbgems: #{GEMNAME}"})"
  if $mrbtest_assert && $mrbtest_assert.size > 0
    $mrbtest_assert.each do |idx, assert_msg, diff|
      msg += "\n - Assertion[#{idx}] Failed: #{assert_msg}\n#{diff}"
    end
  end
  msg += "\nbacktrace:\n\t#{bt.join("\n\t")}" if bt
  msg
end

##
# Verify a code block.
#
# str : A remark which will be printed in case
#       this assertion fails
# iso : The ISO reference code of the feature
#       which will be tested by this
#       assertion
def assert(str = 'Assertion failed', iso = '')
  t_print(str, (iso != '' ? " [#{iso}]" : ''), ' : ') if $mrbtest_verbose
  begin
    $mrbtest_assert = []
    $mrbtest_assert_idx = 0
    yield
    if($mrbtest_assert.size > 0)
      $asserts.push(assertion_string('Fail: ', str, iso))
      $ko_test += 1
      t_print('F')
    else
      $ok_test += 1
      t_print('.')
    end
  rescue MRubyTestSkip => e
    $asserts.push(assertion_string('Skip: ', str, iso, e))
    $skip_test += 1
    t_print('?')
  rescue Exception => e
    bt = e.backtrace if $mrbtest_verbose
    $asserts.push(assertion_string("#{e.class}: ", str, iso, e, bt))
    $kill_test += 1
    t_print('X')
  ensure
    $mrbtest_assert = nil
  end
  t_print("\n") if $mrbtest_verbose
end

def assertion_diff(exp, act)
  "    Expected: #{exp.inspect}\n" +
  "      Actual: #{act.inspect}"
end

def assert_true(ret, msg = nil, diff = nil)
  if $mrbtest_assert
    $mrbtest_assert_idx += 1
    unless ret == true
      msg ||= "Expected #{ret.inspect} to be true"
      diff ||= assertion_diff(true, ret)
      $mrbtest_assert.push([$mrbtest_assert_idx, msg, diff])
    end
  end
  ret
end

def assert_false(ret, msg = nil, diff = nil)
  unless ret == false
    msg ||= "Expected #{ret.inspect} to be false"
    diff ||= assertion_diff(false, ret)
  end
  assert_true(!ret, msg, diff)
  !ret
end

def assert_equal(exp, act_or_msg = nil, msg = nil, &block)
  ret, exp, act, msg = _eval_assertion(:==, exp, act_or_msg, msg, block)
  unless ret
    msg ||= "Expected to be equal"
    diff = assertion_diff(exp, act)
  end
  assert_true(ret, msg, diff)
end

def assert_not_equal(exp, act_or_msg = nil, msg = nil, &block)
  ret, exp, act, msg = _eval_assertion(:==, exp, act_or_msg, msg, block)
  if ret
    msg ||= "Expected to be not equal"
    diff = assertion_diff(exp, act)
  end
  assert_true(!ret, msg, diff)
end

def assert_same(exp, act_or_msg = nil, msg = nil, &block)
  ret, exp, act, msg = _eval_assertion(:equal?, exp, act_or_msg, msg, block)
  unless ret
    msg ||= "Expected #{act.inspect} to be the same object as #{exp.inspect}"
    diff = "    Expected: #{exp.inspect} (class=#{exp.class}, oid=#{exp.__id__})\n" +
           "      Actual: #{act.inspect} (class=#{act.class}, oid=#{act.__id__})"
  end
  assert_true(ret, msg, diff)
end

def assert_not_same(exp, act_or_msg = nil, msg = nil, &block)
  ret, exp, act, msg = _eval_assertion(:equal?, exp, act_or_msg, msg, block)
  if ret
    msg ||= "Expected #{act.inspect} to not be the same object as #{exp.inspect}"
    diff = "    Expected: #{exp.inspect} (class=#{exp.class}, oid=#{exp.__id__})\n" +
           "      Actual: #{act.inspect} (class=#{act.class}, oid=#{act.__id__})"
  end
  assert_true(!ret, msg, diff)
end

def assert_nil(obj, msg = nil)
  unless ret = obj.nil?
    msg ||= "Expected #{obj.inspect} to be nil"
    diff = assertion_diff(nil, obj)
  end
  assert_true(ret, msg, diff)
end

def assert_include(collection, obj, msg = nil)
  unless ret = collection.include?(obj)
    msg ||= "Expected #{collection.inspect} to include #{obj.inspect}"
    diff = "    Collection: #{collection.inspect}\n" +
           "        Object: #{obj.inspect}"
  end
  assert_true(ret, msg, diff)
end

def assert_not_include(collection, obj, msg = nil)
  if ret = collection.include?(obj)
    msg ||= "Expected #{collection.inspect} to not include #{obj.inspect}"
    diff = "    Collection: #{collection.inspect}\n" +
           "        Object: #{obj.inspect}"
  end
  assert_true(!ret, msg, diff)
end

##
# Fails unless +obj+ is a kind of +cls+.
def assert_kind_of(cls, obj, msg = nil)
  unless ret = obj.kind_of?(cls)
    msg ||= "Expected #{obj.inspect} to be a kind of #{cls}, not #{obj.class}"
    diff = assertion_diff(cls, obj.class)
  end
  assert_true(ret, msg, diff)
end

##
# Fails unless +exp+ is equal to +act+ in terms of a Float
def assert_float(exp, act, msg = nil)
  unless ret = check_float(exp, act)
    msg ||= "Float #{exp} expected to be equal to float #{act}"
    diff = assertion_diff(exp, act)
  end
  assert_true(ret, msg, diff)
end

def assert_raise(*exc)
  msg = (exc.last.is_a? String) ? exc.pop : nil
  begin
    yield
  rescue *exc
    assert_true(true)
  rescue Exception => e
    msg ||= "Expected to raise #{exc}, not"
    diff = "      Class: <#{e.class}>\n" +
           "    Message: #{e.message}"
    assert_true(false, msg, diff)
  else
    msg ||= "Expected to raise #{exc} but nothing was raised."
    diff = ""
    assert_true(false, msg, diff)
  end
end

def assert_nothing_raised(msg = nil)
  begin
    yield
  rescue Exception => e
    msg ||= "Expected not to raise #{e} but it raised"
    diff =  "      Class: <#{e.class}>\n" +
            "    Message: #{e.message}"
    assert_true(false, msg, diff)
  else
    assert_true(true)
  end
end

##
# Report the test result and print all assertions
# which were reported broken.
def report()
  t_print("\n")

  $asserts.each do |msg|
    t_print("#{msg}\n")
  end

  $total_test = $ok_test + $ko_test + $kill_test + $skip_test
  t_print("Total: #{$total_test}\n")

  t_print("   OK: #{$ok_test}\n")
  t_print("   KO: #{$ko_test}\n")
  t_print("Crash: #{$kill_test}\n")
  t_print(" Skip: #{$skip_test}\n")

  if Object.const_defined?(:Time)
    t_time = Time.now - $test_start
    t_print(" Time: #{t_time.round(2)} seconds\n")
  end
end

##
# Performs fuzzy check for equality on methods returning floats
def check_float(a, b)
  tolerance = Mrbtest::FLOAT_TOLERANCE
  a = a.to_f
  b = b.to_f
  if a.finite? and b.finite?
    (a-b).abs < tolerance
  else
    true
  end
end

def _eval_assertion(meth, exp, act_or_msg, msg, block)
  if block
    exp, act, msg = exp, block.call, act_or_msg
  else
    exp, act, msg = exp, act_or_msg, msg
  end
  return exp.__send__(meth, act), exp, act, msg
end

##
# Skip the test
class MRubyTestSkip < NotImplementedError; end

def skip(cause = "")
  raise MRubyTestSkip.new(cause)
end
