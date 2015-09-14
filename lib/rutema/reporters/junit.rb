#  Copyright (c) 2015 Vassilis Rizopoulos. All rights reserved.
require 'rexml/document'
require_relative "../core/reporter"

module Rutema
  module Reporters
    #This reporter generates an JUnit style XML result file that can be parsed by CI plugins
    #
    #It has been tested with Jenkins (>1.6.20)
    #
    #The following configuration keys are used by Rutema::Reporters::JUnit
    #
    # filename - the filename to use when saving the report. Default is 'rutema.results.junit.xml'
    #
    #Example configuration:
    #
    # require "rutema/reporters/junit"
    # cfg.reporter={:class=>Rutema::Reporters::JUnit,"filename"=>"rutema.junit.xml"}
    class JUnit<BlockReporter
      DEFAULT_FILENAME="rutema.results.junit.xml"
    
      def initialize configuration,dispatcher
        super(configuration,dispatcher)
        @filename=configuration.reporters.fetch(self.class,{}).fetch("filename",DEFAULT_FILENAME)
      end
      #We get all the data from a test run in here.
      def report specs,states,errors
        tests=[]
        number_of_failed=0
        total_duration=0
        states.each do |k,v|
          tests<<test_case(k,v)
          number_of_failed+=1 if v['status']!=:success
          total_duration+=v["duration"].to_f
        end
        crashes=errors.map{|error| crash(error[:test],error[:error])}

        
        #<testsuite disabled="0" errors="0" failures="1" hostname="" id=""
        #name="" package="" skipped="" tests="" time="" timestamp="">
        attributes={"id"=>@configuration.context[:config_name],
          "name"=>@configuration.context[:config_name],
          "errors"=>crashes.size,
          "failures"=>number_of_failed,
          "tests"=>specs.size,
          "time"=>total_duration,
          "timestamp"=>@configuration.context[:start_time]
        }
        element_suite=REXML::Element.new("testsuite")
        element_suite.add_attributes(attributes)        
        
        crashes.each{|t| element_suite.add_element(t)}
        tests.each{|t| element_suite.add_element(t)}
        xmldoc=REXML::Document.new
        xmldoc<<REXML::XMLDecl.new
        xmldoc.add_element(element_suite)
        
        Rutema::Utilities.write_file(@filename,xmldoc.to_s)
      end
      private
      def test_case name,state
        #<testcase name="" time="">      => the results from executing a test method
        #  <system-out>  => data written to System.out during the test run
        #  <system-err>  => data written to System.err during the test run
        #  <skipped/>    => test was skipped
        #  <failure>     => test failed
        #  <error>       => test encountered an error
        #</testcase>
        element_test=REXML::Element.new("testcase")
        element_test.add_attributes("name"=>name,"time"=>state["duration"],"classname"=>@configuration.context[:config_name])
        if state['status']!=:success
          fail=REXML::Element.new("failure")
          fail.add_attribute("message","Step #{state["steps"].last["number"]} failed.")
          fail.text="Step #{state["steps"].last["number"]} failed."
          element_test.add_element(fail)
          out=REXML::Element.new("system-out")
          out.text=state["steps"].last["out"]
          element_test.add_element(out)
          err=REXML::Element.new("system-err")
          err.text=state["steps"].last["err"]
          element_test.add_element(err)
        end
        return element_test
      end
      
      def crash name,message
        failed=REXML::Element.new("testcase")
        failed.add_attributes("name"=>name,"classname"=>@configuration.context[:config_name],"time"=>0)
        msg=REXML::Element.new("error")
        msg.add_attribute("message",message)
        msg.text=message
        failed.add_element(msg)
        return failed
      end
    end
  end
end
