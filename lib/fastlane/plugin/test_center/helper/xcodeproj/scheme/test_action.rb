module Xcodeproj
    class XCScheme
      class TestAction < AbstractSchemeAction
        def test_plans
          return [] unless @xml_element.elements['TestPlans']

          @xml_element.elements['TestPlans'].get_elements('TestPlanReference').map do |node|
            TestPlanReference.new(node)
          end
        end
      end

      class TestPlanReference < XMLElementWrapper
        def initialize(node)
          create_xml_element_with_fallback(node, 'TestPlanReference') do
          end
        end

        def target_referenced_container
          @xml_element.attributes['reference']
        end
      end
    end
end

