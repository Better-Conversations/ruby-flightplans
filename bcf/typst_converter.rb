require 'tmpdir'
require 'tilt'
require 'tilt/erb'

def format_speakers(speakers)
  if speakers.is_a? Array
    speakers.map { |s| format_speakers(s) }.join(" and ")
  else
    speakers.to_s.capitalize
  end
end

# TODO: It might be good to isolate these into markdown files which we then read back to avoid escaping issues.
#  Implement this when we move to more ERB
def render_markdown(md)
  "cmarker.render(\"#{md}\")"
end

module BCF
  # Typst Intermediate Representation
  module TIR
    TableRow = Struct.new(
      :length,
      :section_info,
      :facilitator_content,
      :producer_content
    )
  end

  class Block
    def table_row
      TIR::TableRow.new(
        length: self.length,
        section_info: section_info,
        facilitator_content: self.facilitator_notes,
        producer_content: self.producer_notes,
      )
    end

    def flipchart
      self.resources.find { |r| r.is_a? BCF::Resource::Flipchart }
    end

    def section_info
      "#{self.name}#linebreak()#bcf-nom[#{format_speakers(self.speaker)}]#linebreak()#{self.flipchart&.inplace_section_comment}#linebreak()#{self.section_comment}"
    end
  end

  class Notes
    def chunk_notes
      # First we group adjacent spoken items together
      groups = []

      self.items.each do |item|
        if item.is_a?(Spoken)
          last_group = groups.last

          if last_group.is_a? SpokenGroup
            last_group.lines << item
          else
            groups << SpokenGroup.new(lines: [item])
          end
        else
          groups << item
        end
      end

      groups
    end

    def to_typst
      groups = chunk_notes
      groups.map(&:to_typst).join("\n\n")
    end
  end

  SpokenGroup = Struct.new(:lines) do
    def to_typst
      "#spoken(
          #{self.lines.map(&:to_typst_expr).join(",\n")}
        )"
    end
  end

  class Instruction
    def to_typst
      "#instruction(#{render_markdown(self.content)})"
    end
  end

  class Spoken
    # This is named differently as it provides a code expression not a content string
    def to_typst_expr
      if self.fixed
        "bcf-cue(#{render_markdown(self.content)})"
      else
        render_markdown(self.content)
      end
    end
  end

  class Chat
    def to_typst
      "#chat(#{render_markdown(self.content)})"
    end
  end

  class FlightPlanRenderContext
    def initialize(flight_plan)
      @flight_plan = flight_plan
    end

    def render_content(content)
      return "" if content.nil?
      return content if content.is_a? String

      Tilt.new('typst_erb/render_content.typ.erb')
          .render(self, content: content)
    end

    def render_note(note)
      Tilt.new('typst_erb/render_note.typ.erb')
          .render(self, note: note)
    end

    private def method_missing(name, *args)
      @flight_plan.send(name, *args)
    end
  end

  class FlightPlan
    def to_typst
      template = Tilt.new('typst_erb/entry_point.typ.erb')
      template.render(FlightPlanRenderContext.new(self))
    end

    def render_pdf(output_path, debug_typst_path = nil)
      Dir.mktmpdir do |dir|
        # Copy all files from ./typst to the temp directory
        Dir.glob(File.join(File.dirname(__FILE__), "..", 'typst_erb', '*')).each do |file|
          FileUtils.cp(file, dir)
        end

        typst_path = File.join(dir, 'output.typ')
        typst_content = self.to_typst
        File.write(typst_path, typst_content)

        system("typstyle -i #{typst_path}")
        FileUtils.cp(typst_path, debug_typst_path) if debug_typst_path

        system("typst c #{typst_path} #{output_path}")
      end
    end
  end
end
