<%
Class Mustache
    '''
    ' This class renders Mustache templates.  http://mustache.github.com/
    ' To use:  Mustache.render(template_string, context_dictionary)
    ' 
    ' Features implemented so far:
    '   - variable tags
    '   - unescaped variable tags for raw HTML
    '   - section tags (no support for lambdas)
    '''

    Function make_regex(pattern)
        ''' Basic regex factory '''
        Dim r : Set r = New RegExp
        r.Global = True
        r.MultiLine = True
        r.Pattern = pattern
        Set make_regex = r
    End Function

    Function make_variable_tag_regex(tag, escape)
        ''' Variable tag regex factory '''
        Dim pattern 
        If escape Then
            pattern = "\{\{\s*" & tag & "\s*\}\}"
        Else
            pattern = "\{\{\{\s*" & tag & "\s*\}\}\}"
        End If
        Set make_variable_tag_regex = Me.make_regex(pattern)
    End Function

    Function regex_match(subject, pattern)
        ''' Return a dictionary with regex match data. '''
        Dim re : Set re = Me.make_regex(pattern)
        re.Global = False
        Dim matches : Set matches = re.Execute(subject)
        Dim match
        Dim r : Set r = Server.CreateObject("Scripting.Dictionary")
        For Each match In matches
            ' We only need the first one since we set Global = False
            r.Add "start_index", match.FirstIndex
            r.Add "end_index", match.FirstIndex + match.Length
            'r.Add "length", match.Length  ' Not needed for now
            'r.Add "value", match.Value
            r.Add "key", match.SubMatches(0)
            r.Add "template", match.SubMatches(1)
            Exit For
        Next
        Set regex_match = r
    End Function

    Function parse_variable_tags(template, context, escape)
        ''' Go through the context dictionary and do a search and replace. '''
        Dim r : r = template
        Dim re

        Dim key
        For Each key In context
            If TypeName(context(key)) = "String" Then
                Dim content
                If escape Then
                    content = Server.HTMLEncode(context(key))
                Else
                    content = context(key)
                End If
                Set re = Me.make_variable_tag_regex(key, escape)
                r = re.Replace(r, content)
            End If
        Next

        parse_variable_tags = r
    End Function

    Function parse_section_tag(template, context)
        ''' Parse the first section tag in the template. '''
        Dim r : r = template
        Dim section
        Set section = Me.regex_match(r, "\{\{#\s*(\w*)\s*\}\}((.|[\r\n])*?)\{\{/\s*\1\s*\}\}")

        Dim key : key = ""
        Dim tmpl : tmpl = ""
        If section.Exists("key") Then
            key = section("key")
            tmpl = section("template")
        End If

        Dim parsed_section : parsed_section = ""
        If key <> "" And context.Exists(key) Then
            ' Handle the different data types that can be the section key.
            If IsArray(context(key)) Then
                Dim dict
                For Each dict In context(key)
                    parsed_section = parsed_section & Me.render(tmpl, dict)
                Next
            ElseIf TypeName(context(key)) = "Boolean" Then
                If context(key) Then
                    parsed_section = tmpl
                End If
            ElseIf TypeName(context(key)) = "Dictionary" Then
                parsed_section = Me.render(tmpl, context(key))
            End If
        End If
        r = Me.replace_(r, parsed_section, section("start_index"), section("end_index"))
        parse_section_tag = r
    End Function

    Function replace_(subject, replace_with, start_index, end_index)
        ''' Replace `subject` from `start_index` to `end_index` with `replace_with`. '''
        Dim r : r = subject  ' default
        If subject <> "" Then
            r = Left(subject, start_index)
            r = r & replace_with
            r = r & Right(subject, Len(subject) - end_index)
        End If
        replace_ = r
    End Function

    Function cleanup(template)
        Dim r : r = template
        ''' Remove leftover variable tags still left in template. '''
        Dim re : Set re = Me.make_variable_tag_regex("\w*", False)  ' {{{ x }}}
        r = re.Replace(r, "")
        Set re = Me.make_variable_tag_regex("\w*", True)  ' {{ x }}
        r = re.Replace(r, "")
        cleanup = r
    End Function

    Function render(template_string, context_dictionary)
        ''' The main rendering method of the class.  '''
        Dim tmpl : tmpl = template_string
        Dim d : Set d = context_dictionary
        Dim r : r = tmpl

        ' Keep parsing sections til there is no more.
        Dim tmp
        Do
            tmp = r
            r = Me.parse_section_tag(r, d)
        Loop While tmp <> r

        ' Parse variable tags.
        ' Do unescaped tags first.
        r = Me.parse_variable_tags(r, d, False)
        r = Me.parse_variable_tags(r, d, True)

        r = Me.cleanup(r)

        render = r
    End Function

End Class
%>
