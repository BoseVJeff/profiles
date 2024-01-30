function Convert-InternalHTMLToText {
    [CmdletBinding()]
    param(
        [string] $Content
    )
    $Output = [NUglify.Uglify]::HtmlToText($Content)
    if ($Output.HasErrors) {
        Write-Warning "Convert-HTMLToText -Errors: $($Output.Errors)"
    }
    $Output.Code
}
function ConvertFrom-HTMLTableAgilityPack {
    [cmdletbinding()]
    param(
        [Uri] $Url,
        [string] $Content,
        [System.Collections.IDictionary] $ReplaceContent,
        [System.Collections.IDictionary] $ReplaceHeaders,
        [switch] $ReverseTable
    )
    Begin {
        # Workaround for Agility Pack
        # https://www.codetable.net/decimal/173
        $Replacements = @{
            "&#60;"  = "<";
            "&#62;"  = ">";
            "&#32;"  = " ";
            "&#31;"  = "?";
            "&#34;"  = "\";
            "&#39;"  = "'";
            "&#38;"  = "&";
            "&#40;"  = "(";
            "&#41;"  = ")";
            "&#58;"  = ":";
            "&#59;"  = ";";
            "&#61;"  = "=";
            "&#91;"  = "[";
            "&#93;"  = "]";
            "&#123;" = "{";
            "&#125;" = "}";
            "&#124;" = "|";
            "&#160;" = " ";
            "&#173;" = "-";
            "&amp;"  = "&";
        }
    }
    Process {
        if ($Content) {
            [HtmlAgilityPack.HtmlDocument] $HtmlDocument = [HtmlAgilityPack.HtmlDocument]::new()
            $HtmlDocument.LoadHtml($Content)
        } else {
            # It seems there's a problem with detecting encoding in HAP
            # https://github.com/zzzprojects/html-agility-pack/issues/320
            # The workaround is to load the page once to get encoding
            # and once loaded, reload to get with prtoper encoding
            [HtmlAgilityPack.HtmlWeb] $HtmlWeb = [HtmlAgilityPack.HtmlWeb]::new()
            [HtmlAgilityPack.HtmlDocument] $HtmlDocument = $HtmlWeb.Load($url)
            $DetectedEncoding = $HtmlDocument.Encoding

            # Workaround for HAP bug
            [HtmlAgilityPack.HtmlWeb] $HtmlWeb = [HtmlAgilityPack.HtmlWeb]::new()
            $HtmlWeb.AutoDetectEncoding = $false
            $HtmlWeb.OverrideEncoding = $DetectedEncoding
            [HtmlAgilityPack.HtmlDocument] $HtmlDocument = $HtmlWeb.Load($url)
        }
        [Array] $Tables = $HtmlDocument.DocumentNode.SelectNodes("//table")


        [Array] $OutputTables = :table foreach ($table in $Tables) {
            $Rows = $table.SelectNodes('.//tr')
            #$Rows | Format-Table -Property ChildNodes,InnerHtml, Line
            if ($ReverseTable) {
                $Count = 0
                [Array] $TableContent = @(
                    $obj = [ordered] @{ }
                    $TableContent = foreach ($Row in $Rows) {
                        $Count++

                        [string] $CellHeader = $row.SelectNodes("th").InnerText
                        # Converting to Unicode Decimal Code
                        foreach ($R in $Replacements.Keys) {
                            $CellHeader = $CellHeader -replace $R, $Replacements[$R]
                        }

                        [string] $CellContent = $row.SelectNodes("td").InnerText
                        $CellContent = $CellContent.Trim()
                        if ($ReplaceContent) {
                            foreach ($Key in $ReplaceContent.Keys) {
                                $CellContent = $CellContent -replace $Key, $ReplaceContent[$Key]
                            }
                        }
                        # Converting to Unicode Decimal Code
                        foreach ($R in $Replacements.Keys) {
                            $CellContent = $CellContent -replace $R, $Replacements[$R]
                        }
                        # Assign to object
                        if ($CellHeader) {
                            $obj["$($CellHeader)"] = $CellContent
                        } else {
                            $obj["$Count"] = $CellContent
                        }
                    }
                    $obj
                )
            } else {
                $Headers = foreach ($Row in $Rows[0]) {
                    foreach ($Cell in $row.SelectNodes("th|td")) {
                        $CellContent = $Cell.InnerText.Trim()
                        if ($ReplaceHeaders) {
                            foreach ($Key in $ReplaceHeaders.Keys) {
                                $CellContent = $CellContent -replace $Key, $ReplaceHeaders.$Key
                            }
                        }
                        # Converting to Unicode Decimal Code to get rid of special chars like &#160;
                        foreach ($R in $Replacements.Keys) {
                            $CellContent = $CellContent -replace $R, $Replacements[$R]
                        }
                        $CellContent
                    }
                }
                $TableContent = foreach ($Row in $Rows | Select-Object -Skip 1) {
                    $obj = [ordered] @{ }
                    for ($x = 0; $x -lt $headers.count; $x++) {
                        [string] $CellContent = $row.SelectNodes("th|td")[$x].InnerText
                        $CellContent = $CellContent.Trim()
                        if ($ReplaceContent) {
                            foreach ($Key in $ReplaceContent.Keys) {
                                $CellContent = $CellContent -replace $Key, $ReplaceContent.$Key
                            }
                        }
                        # Converting to Unicode Decimal Code to get rid of special chars like &#160;
                        foreach ($R in $Replacements.Keys) {
                            $CellContent = $CellContent -replace $R, $Replacements[$R]
                        }
                        # Assign to object
                        if ($($headers[$x])) {
                            $obj["$($headers[$x])"] = $CellContent
                        } else {
                            $obj["$x"] = $CellContent
                        }
                    }
                    [PSCustomObject] $obj
                }
            }
            @(, $TableContent)
        }
        $OutputTables
    }
    End { }
}
function ConvertFrom-HTMLTableAngle {
    [cmdletbinding()]
    param(
        [Uri] $Url,
        [string] $Content,
        [System.Collections.IDictionary] $ReplaceContent,
        [System.Collections.IDictionary] $ReplaceHeaders
    )
    Begin { }
    Process {
        if ($Url) {
            $Content = (Invoke-WebRequest -Uri $Url).Content
        }
        if (-not $Content) {
            return
        }
        # Initialize the parser
        $HTMLParser = [AngleSharp.Html.Parser.HtmlParser]::new()
        # Load the html
        $ParsedDocument = $HTMLParser.ParseDocument($Content)

        # Get all the tables
        [Array] $Tables = $ParsedDocument.GetElementsByTagName('table')

        # For each table
        :table foreach ($table in $tables) {
            [Array] $headers = foreach ($_ in $Table.Rows[0].Cells) {
                $CellContent = $_.TextContent.Trim()
                if ($ReplaceHeaders) {
                    foreach ($Key in $ReplaceHeaders.Keys) {
                        $CellContent = $CellContent -replace $Key, $ReplaceHeaders.$Key
                    }
                }
                $CellContent
            }

            # if headers have value
            if ($Headers.Count -ge 1) {
                [Array] $output = foreach ($row in $table.Rows | Select-Object -Skip 1) {

                    $obj = [ordered]@{ }
                    # add all the properties, one per row
                    for ($x = 0; $x -lt $headers.count; $x++) {
                        if ($($headers[$x])) {
                            if ($row.Cells[$x].TextContent) {
                                $CellContent = $row.Cells[$x].TextContent.Trim()
                                if ($ReplaceContent) {
                                    foreach ($Key in $ReplaceContent.Keys) {
                                        $CellContent = $CellContent -replace $Key, $ReplaceContent.$Key
                                    }
                                }
                                $obj["$($headers[$x])"] = $CellContent
                            } else {
                                $obj["$($headers[$x])"] = $row.Cells[$x].TextContent
                            }
                        } else {
                            $obj["$x"] = $row.Cells[$x].TextContent #.Trim()
                        }
                    }
                    [PSCustomObject] $obj
                }
                # if there are any rows, output
                if ($output.count -ge 1) {
                    @(, $output)
                } else {
                    Write-Verbose 'ConvertFrom-HtmlTable - Table has no rows. Skipping'
                }
            }
        }
    }
    End { }
}
function Format-InternalCSS {
    [CmdletBinding()]
    param(
        [string] $Content
    )
    $CssParser = [AngleSharp.Css.Parser.CssParser]::new()
    $ParsedDocument = $CssParser.ParseStyleSheet($Content)
    $StringWriter = [System.IO.StringWriter]::new()
    $PrettyMarkupFormatter = [AngleSharp.Css.CssStyleFormatter]::new()
    $ParsedDocument.ToCss($StringWriter, $PrettyMarkupFormatter)
    $StringWriter.ToString()
}
function Format-InternalFormatWithUglify {
    [CmdletBinding()]
    param(
        [string] $Content,
        [string] $Indent = '    ',
        [NUglify.BlockStart] $BlockStartLine = [NUglify.BlockStart]::SameLine,
        [switch] $RemoveOptionalTags,
        [switch] $OutputTextNodesOnNewLine,
        [switch] $RemoveEmptyAttributes,
        [switch] $AlphabeticallyOrderAttributes,
        [switch] $RemoveEmptyBlocks,
        [switch] $RemoveComments,
        [switch] $IsFragment
    )
    $Settings = [NUglify.Html.HtmlSettings]::new()
    # HTML Settings
    if ($IsFragment) {
        $Settings.IsFragmentOnly = $true
    }
    # Keep first comment
    # $Pattern = "<!-- saved from url=\(0014\)about:internet -->"
    # $MOTW = [System.Text.RegularExpressions.Regex]::new($Pattern) #, [System.Text.RegularExpressions.RegexOptions]::MultiLine)
    # $Settings.KeepCommentsRegex.Add($MOTW)

    $Settings.RemoveOptionalTags = $RemoveOptionalTags.IsPresent
    $Settings.PrettyPrint = $true
    $Settings.Indent = $Indent
    $Settings.OutputTextNodesOnNewLine = $OutputTextNodesOnNewLine.IsPresent # option to not indent textnodes when theyre the only child
    $Settings.RemoveEmptyAttributes = $RemoveEmptyAttributes.IsPresent
    $Settings.AlphabeticallyOrderAttributes = $AlphabeticallyOrderAttributes.IsPresent
    $Settings.RemoveComments = $RemoveComments
    $Settings.RemoveQuotedAttributes = $false
    #$Settings.LineTerminator = [System.Environment]::NewLine
    # JS Settings
    $Settings.JsSettings.MinifyCode = $true
    $Settings.JsSettings.OutputMode = [NUglify.OutputMode]::MultipleLines
    $Settings.JsSettings.Indent = $Indent
    $Settings.JsSettings.BlocksStartOnSameLine = $BlockStartLine
    $Settings.JsSettings.PreserveFunctionNames = $true
    $Settings.JsSettings.LocalRenaming = [NUglify.JavaScript.LocalRenaming]::KeepAll
    #$Settings.JsSettings.EvalTreatment = [NUglify.JavaScript.EvalTreatment]::Ignore
    #$Settings.JsSettings.Format = [NUglify.JavaScript.JavaScriptFormat]::Normal
    $Settings.JsSettings.NoAutoRenameList = $true
    $Settings.JsSettings.PreserveFunctionNames = $true
    #$Settings.JsSettings.CollapseToLiteral = $true
    #$Settings.JsSettings.ConstStatementsMozilla = $true
    #$Settings.JsSettings.LineBreakThreshold = 50
    $Settings.JsSettings.ReorderScopeDeclarations = $false
    #$Settings.JsSettings.RenamePairs = $false
    #$Settings.JsSettings.QuoteObjectLiteralProperties = $true
    $Settings.JsSettings.TermSemicolons = $true
    #$Settings.JsSettings.Format = [NUglify.JavaScript.JavaScriptFormat]::Normal
    $Settings.JsSettings.RemoveUnneededCode = $false;
    $Settings.JsSettings.RemoveFunctionExpressionNames = $false;
    # $Settings.NoAutoRenameCollection  # ReadOnly
    #$Settings.JsSettings.LineTerminator = "`r`n"
    # CSS Settings
    $Settings.CssSettings.OutputMode = [NUglify.OutputMode]::MultipleLines
    $Settings.CssSettings.Indent = $Indent
    $Settings.CssSettings.BlocksStartOnSameLine = $BlockStartLine
    $Settings.CssSettings.RemoveEmptyBlocks = $RemoveEmptyBlocks
    $Settings.CssSettings.DecodeEscapes = $false
    #$Settings.CssSettings.LineTerminator = "`r`n"
    [NUglify.Uglify]::Html($Content, $Settings).Code
}

function Format-InternalHTML {
    [CmdletBinding()]
    param(
        [string] $Content
    )
    $HTMLParser = [AngleSharp.Html.Parser.HtmlParser]::new()
    $ParsedDocument = $HTMLParser.ParseDocument($Content)
    $StringWriter = [System.IO.StringWriter]::new()
    $PrettyMarkupFormatter = [AngleSharp.Html.PrettyMarkupFormatter]::new()
    $ParsedDocument.ToHtml($StringWriter, $PrettyMarkupFormatter)
    $StringWriter.ToString()
}
function Format-InternalJS {
    [CmdletBinding()]
    param(
        [string] $Content,
        [int] $IndentSize = 4,
        [string] $IndentChar = ' ',
        [bool] $IndentWithTabs = $false,
        [bool] $PreserveNewlines = $true,
        [double] $MaxPreserveNewlines = 10.0,
        [bool] $JslintHappy = $false,
        [Jsbeautifier.BraceStyle] $BraceStyle = [Jsbeautifier.BraceStyle]::Collapse,
        [bool] $KeepArrayIndentation = $false,
        [bool] $KeepFunctionIndentation = $false,
        [bool] $EvalCode = $false,
        #[int] $WrapLineLength = 0,
        [bool] $BreakChainedMethods = $false
    )
    $Jsbeautifier = [Jsbeautifier.Beautifier]::new()
    $Jsbeautifier.Opts.IndentSize = $IndentSize
    $Jsbeautifier.Opts.IndentChar = $IndentChar
    $Jsbeautifier.Opts.IndentWithTabs = $IndentWithTabs
    $Jsbeautifier.Opts.PreserveNewlines = $PreserveNewlines
    $Jsbeautifier.Opts.MaxPreserveNewlines = $MaxPreserveNewlines
    $Jsbeautifier.Opts.JslintHappy = $JslintHappy
    $Jsbeautifier.Opts.BraceStyle = $BraceStyle
    $Jsbeautifier.Opts.KeepArrayIndentation = $KeepArrayIndentation
    $Jsbeautifier.Opts.KeepFunctionIndentation = $KeepFunctionIndentation
    $Jsbeautifier.Opts.EvalCode = $EvalCode
    #$Jsbeautifier.Opts.WrapLineLength = $WrapLineLength
    $Jsbeautifier.Opts.BreakChainedMethods = $BreakChainedMethods

    #$Jsbeautifier.Flags
    <#
    public BeautifierFlags(string mode)
    {
        PreviousMode = "BLOCK";
        Mode = mode;
        VarLine = false;
        VarLineTainted = false;
        VarLineReindented = false;
        InHtmlComment = false;
        IfLine = false;
        ChainExtraIndentation = 0;
        InCase = false;
        InCaseStatement = false;
        CaseBody = false;
        IndentationLevel = 0;
        TernaryDepth = 0;
    }
    #>
    $FormattedJS = $Jsbeautifier.Beautify($Content)
    $FormattedJS
}
function Format-InternalUglifyJS {
    [CmdletBinding()]
    param(
        [string] $Content
    )
    $Settings = [NUglify.JavaScript.CodeSettings]::new()
    $Settings.MinifyCode = $true
    $Settings.OutputMode = [NUglify.OutputMode]::MultipleLines
    $Settings.Indent = $Indent
    $Settings.LocalRenaming = [NUglify.JavaScript.LocalRenaming]::KeepAll
    #$Settings.EvalTreatment = [NUglify.JavaScript.EvalTreatment]::Ignore
    #$Settings.Format = [NUglify.JavaScript.JavaScriptFormat]::Normal
    $Settings.Indent = '    '
    $Settings.NoAutoRenameList = $true
    $Settings.PreserveFunctionNames = $true
    # $Settings.NoAutoRenameCollection  # ReadOnly
    [NUglify.Uglify]::Js($Content, $Code).Code
}
function Optimize-InternalCSS {
    [CmdletBinding()]
    param(
        [string] $Content
    )
    $CSSParser = [AngleSharp.Css.Parser.CssParser]::new()
    $ParsedDocument = $CSSParser.ParseStyleSheet($Content)
    $StringWriter = [System.IO.StringWriter]::new()
    $PrettyMarkupFormatter = [AngleSharp.Css.MinifyStyleFormatter]::new()
    $ParsedDocument.ToCss($StringWriter, $PrettyMarkupFormatter)
    $StringWriter.ToString()
}
function Optimize-InternalUglifyCSS {
    [CmdletBinding()]
    param(
        [string] $Content
    )
    $Settings = [NUglify.Css.CssSettings]::new()
    $Settings.DecodeEscapes = $false
    [NUglify.Uglify]::Css($Content, $Settings).Code
}
function Optimize-InternalUglifyHTML {
    [CmdletBinding()]
    param(
        [string] $Content,
        [switch] $CSSDecodeEscapes
    )

    $Settings = [NUglify.Html.HtmlSettings]::new()
    $Settings.RemoveOptionalTags = $false
    $Settings.CssSettings.DecodeEscapes = $CSSDecodeEscapes.IsPresent
    # Keep first comment
    #$Pattern = "<!-- saved from url=\(0014\)about:internet -->"
    #$Pattern = "^\ssaved\sfrom\url="
    #$MOTW = [System.Text.RegularExpressions.Regex]::new($Pattern, [System.Text.RegularExpressions.RegexOptions]::MultiLine)
    #$Settings.KeepCommentsRegex.Add($MOTW)

    if ($Content -like "*<!-- saved from url=(0014)about:internet -->*") {
        $MOTW = "<!-- saved from url=(0014)about:internet -->"
    } else {
        $MOTW = ''
    }
    $Settings.RemoveComments = $true
    $Output = [NUglify.Uglify]::Html($Content, $Settings).Code
    if ($MOTW) {
        $MOTW + [System.Environment]::NewLine + $Output
    } else {
        $Output
    }
}

<# $Settings
AttributesCaseSensitive           : False
CollapseWhitespaces               : True
RemoveComments                    : True
RemoveOptionalTags                : False
RemoveInvalidClosingTags          : True
RemoveEmptyAttributes             : True
RemoveQuotedAttributes            : True
DecodeEntityCharacters            : True
AttributeQuoteChar                :
RemoveScriptStyleTypeAttribute    : True
ShortBooleanAttribute             : True
IsFragmentOnly                    : False
MinifyJs                          : True
JsSettings                        : NUglify.JavaScript.CodeSettings
MinifyCss                         : True
MinifyCssAttributes               : True
CssSettings                       : NUglify.Css.CssSettings
PrettyPrint                       : False
RemoveJavaScript                  : False
InlineTagsPreservingSpacesAround  : {[a, True], [abbr, True], [acronym, True], [b, True]...}
KeepOneSpaceWhenCollapsing        : False
TagsWithNonCollapsableWhitespaces : {[pre, True], [textarea, True]}
KeepCommentsRegex                 : {^!, ^/?ko(?:[\s\-]|$)}
KeepTags                          : {}
RemoveAttributes                  : {}
AlphabeticallyOrderAttributes     : False
#>

<# $Settings.JsSettings

HasRenamePairs                : False
RenamePairs                   :
NoAutoRenameCollection        : {$super}
NoAutoRenameList              : $super
KnownGlobalCollection         : {}
KnownGlobalNamesList          :
DebugLookupCollection         : {}
DebugLookupList               :
AlwaysEscapeNonAscii          : False
AmdSupport                    : False
CollapseToLiteral             : True
ConstStatementsMozilla        : False
ErrorIfNotInlineSafe          : False
EvalLiteralExpressions        : True
EvalTreatment                 : Ignore
Format                        : Normal
IgnoreConditionalCompilation  : False
IgnorePreprocessorDefines     : False
InlineSafeStrings             : True
LocalRenaming                 : CrunchAll
MacSafariQuirks               : True
MinifyCode                    : True
ManualRenamesProperties       : True
PreprocessOnly                : False
PreserveFunctionNames         : False
PreserveImportantComments     : True
QuoteObjectLiteralProperties  : False
ReorderScopeDeclarations      : True
RemoveFunctionExpressionNames : True
RemoveUnneededCode            : True
ScriptVersion                 : None
SourceMode                    : Program
StrictMode                    : False
StripDebugStatements          : True
SymbolsMap                    :
WarningLevel                  : 0
AllowEmbeddedAspNetBlocks     : False
BlocksStartOnSameLine         : NewLine
IgnoreAllErrors               : False
IndentSize                    : 4
LineBreakThreshold            : 2147482647
OutputMode                    : SingleLine
TermSemicolons                : False
KillSwitch                    : 0
LineTerminator                :

IgnoreErrorCollection         : {}
IgnoreErrorList               :
PreprocessorValues            : {}
PreprocessorDefineList        :
ResourceStrings               : {}
ReplacementTokens             : {}
ReplacementFallbacks          : {}
#>

<# $Settings.CssSettings
ColorNames                : Hex
CommentMode               : Important
MinifyExpressions         : True
CssType                   : FullStyleSheet
RemoveEmptyBlocks         : True
FixIE8Fonts               : True
ExcludeVendorPrefixes     : {}
IgnoreRazorEscapeSequence : False
DecodeEscapes             : True
WarningLevel              : 0
AllowEmbeddedAspNetBlocks : False
BlocksStartOnSameLine     : NewLine
IgnoreAllErrors           : False
IndentSize                : 4
LineBreakThreshold        : 2147482647
OutputMode                : SingleLine
TermSemicolons            : False
KillSwitch                : 0
LineTerminator            :

IgnoreErrorCollection     : {}
IgnoreErrorList           :
PreprocessorValues        : {}
PreprocessorDefineList    :
ResourceStrings           : {}
ReplacementTokens         : {}
ReplacementFallbacks      : {}
#>
function Optimize-InternalUglifyJS {
    [CmdletBinding()]
    param(
        [string] $Content,
        [string] $Indent = '    '
    )
    #$Settings = [NUglify.JavaScript.CodeSettings]::new()
    #$Settings.MinifyCode = $true
    #$Settings.OutputMode = [NUglify.OutputMode]::MultipleLines
    #$Settings.Indent = $Indent
    #$Settings.JsSettings.MinifyCode = $true
    #$Settings.JsSettings.OutputMode = [NUglify.OutputMode]::MultipleLines
    #$Settings.JsSettings.Indent = $Indent
    #$Settings.JsSettings.BlocksStartOnSameLine = $BlockStartLine
    [NUglify.Uglify]::Js($Content).Code
}
function Convert-HTMLToText {
    <#
    .SYNOPSIS
    Converts HTML to text.

    .DESCRIPTION
    Converts HTML to text. Simple in it's form it extracts only Text from HTML, regardless of it's structure.

    .PARAMETER File
    Provide HTML file to be converted to PowerShell object.

    .PARAMETER OutputFile
    Parameter description

    .PARAMETER Content
    Provide HTML content to be converted to PowerShell object.

    .PARAMETER URI
    Provide URL to be converted to PowerShell object.

    .EXAMPLE
    $HTMLContentFormatted = @"
    <html>
            <!-- HEADER -->
            <head>
                    <meta charset="utf-8">
                    <meta content="width=device-width, initial-scale=1" name="viewport">
                    <meta name="author">
                    <meta content="2019-08-09 11:26:37" name="revised">
                    <title>My title</title>
                    <!-- CSS Default fonts START -->
                    <link href="https://fonts.googleapis.com/css?family=Roboto|Hammersmith+One|Questrial|Oswald" type="text/css" rel="stylesheet">
                    <!-- CSS Default fonts END -->
                    <!-- CSS Default fonts icons START -->
                    <link href="https://use.fontawesome.com/releases/v5.7.2/css/all.css" type="text/css" rel="stylesheet">
                    <!-- CSS Default fonts icons END -->
            </head>
            <body>
                    <div class="flexElement overflowHidden">
                            <table id="DT-hZRTQIVT" class="display compact">
                                    <thead>
                                            <tr>
                                                    <th>Name</th>
                                                    <th class="none">Id</th>
                                                    <th class="none">HandleCount</th>
                                                    <th>WorkingSet</th>
                                            </tr>
                                    </thead>
                                    <tbody>
                                            <tr>
                                                    <td>1Password</td>
                                                    <td>22268</td>
                                                    <td>1007</td>
                                                    <td>87146496</td>
                                            </tr>
                                            <tr>
                                                    <td>aesm_service</td>
                                                    <td>25340</td>
                                                    <td>189</td>
                                                    <td>3948544</td>
                                            </tr>
                                    </tbody>
                            </table>
                    </div>
                    <footer></footer>
                    <!-- END FOOTER -->
            </body>
            <!-- END BODY -->
            <!-- FOOTER -->
    </html>
    "@

    Convert-HTMLToText -Content $HTMLContentFormatted

    .NOTES
    General notes
    #>
    [CmdletBinding()]
    param(
        [string] $File,
        [string] $OutputFile,
        [Parameter(Mandatory, ParameterSetName = 'Content', ValueFromPipeline, ValueFromPipelineByPropertyName)][string]$Content,
        [alias('Uri')][Parameter(Mandatory, ParameterSetName = 'Uri')][Uri] $Url
    )
    # Load from file or text
    if ($File) {
        if (Test-Path -LiteralPath $File) {
            $Content = [IO.File]::ReadAllText($File)
        } else {
            Write-Warning "Convert-HTMLToText - File doesn't exists"
            return
        }
    } elseif ($Content) {

    } else {
        Write-Warning 'Convert-HTMLToText - No choice file or Content. Termninated.'
        return
    }

    $Output = Convert-InternalHTMLToText -Content $Content

    # Output to file or to text
    if ($OutputFile) {
        [IO.File]::WriteAllText($OutputFile, $Output)
    } else {
        $Output
    }
}
function ConvertFrom-HTML {
    <#
    .SYNOPSIS
    Converts HTML to PowerShell object that can be further digested in PowerShell

    .DESCRIPTION
    Converts HTML to PowerShell object that can be further digested in PowerShell.
    To be used if ConvertTo-HTMLAttributes or ConvertTo-HTMLTable are not enough.

    .PARAMETER Content
    Provide HTML content to be converted to PowerShell object.

    .PARAMETER Url
    Provide URL to be converted to PowerShell object.

    .PARAMETER Engine
    Define engin to be used for conversion. Options are AgilityPack and AngleSharp.
    Both do similar stuff, but slightly in different way giving different PowerShell objects.
    Default is AgilityPack.

    .PARAMETER Raw
    Tells the function to return DocumentNode/DocumentElement instead of root object, which holds more information, that may not be nessecary for day to day use.

    .EXAMPLE
    # Option 1 - uses Agility Pack
    $PageHTML = ConvertFrom-HTML -URL "https://www.evotec.xyz"
    $PageHTML

    .EXAMPLE
    # Option 2 - uses AngleSharp
    $PageHTML = ConvertFrom-HTML -URL "https://www.evotec.xyz" -Engine AngleSharp
    $PageHTML

    .NOTES
    General notes
    #>
    [cmdletbinding(DefaultParameterSetName = 'Uri')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Content', ValueFromPipeline, ValueFromPipelineByPropertyName)][string]$Content,
        [alias('Uri')][Parameter(Mandatory, ParameterSetName = 'Uri')][Uri] $Url,
        [ValidateSet('AngleSharp', 'AgilityPack')] $Engine = 'AgilityPack',
        [switch] $Raw
    )
    Begin {

    }
    Process {
        if ($Engine -eq 'AngleSharp') {
            # Initialize the parser
            $HTMLParser = [AngleSharp.Html.Parser.HtmlParser]::new()
            # Load the html
            if ($Url) {
                $Content = (Invoke-WebRequest -Uri $Url).Content
            }
            if (-not $Content) {
                return
            }
            $ParsedDocument = $HTMLParser.ParseDocument($content)
            if ($Raw) {
                $ParsedDocument
            } else {
                $ParsedDocument.DocumentElement
            }
        } else {
            if ($Content) {
                [HtmlAgilityPack.HtmlDocument] $HtmlDocument = [HtmlAgilityPack.HtmlDocument]::new()
                $HtmlDocument.LoadHtml($Content)
            } else {
                [HtmlAgilityPack.HtmlWeb] $HtmlWeb = [HtmlAgilityPack.HtmlWeb]::new()
                [HtmlAgilityPack.HtmlDocument] $HtmlDocument = $HtmlWeb.Load($url)
            }
            if ($Raw) {
                $HtmlDocument
            } else {
                $HTMLDocument.DocumentNode
            }
        }
    }
    End {
        # Clean up
        $ParsedDocument = $null
        $HtmlDocument = $null
        $HTMLParser = $null
    }
}
function ConvertFrom-HTMLAttributes {
    [alias('ConvertFrom-HTMLTag', 'ConvertFrom-HTMLClass')]
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true)][Array] $Content,
        [string] $Tag,
        [string] $Class,
        [string] $Id,
        [string] $Name,
        [switch] $ReturnObject
    )
    Begin {
        # Initialize the parser
        $HTMLParser = [AngleSharp.Html.Parser.HtmlParser]::new()
    }
    Process {
        # Load the html
        $ParsedDocument = $HTMLParser.ParseDocument($content)
        # Get all the tables
        if ($Tag) {
            [Array] $OutputContent = $ParsedDocument.GetElementsByTagName($Tag)
        } elseif ($Class) {
            [Array] $OutputContent = $ParsedDocument.GetElementsByClassName($Class)
        } elseif ($Id) {
            [Array] $OutputContent = $ParsedDocument.GetElementById($Id)
        } elseif ($Name) {
            [Array] $OutputContent = $ParsedDocument.GetElementsByName($Name)
        }
        if ($OutputContent) {
            if ($ReturnObject) {
                $OutputContent
            } else {
                $OutputContent.TextContent
            }
        }
    }
    End { }
}
Function ConvertFrom-HtmlTable {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Content', ValueFromPipeline, ValueFromPipelineByPropertyName)][string]$Content,
        [alias('Uri')][Parameter(Mandatory, ParameterSetName = 'Uri')][Uri] $Url,
        [System.Collections.IDictionary] $ReplaceContent,
        [System.Collections.IDictionary] $ReplaceHeaders,
        [ValidateSet('AngleSharp', 'AgilityPack')] $Engine,
        [switch] $ReverseTable
    )
    Begin {
        # This fixes an issue https://github.com/PowerShell/PowerShell/issues/11287 for ConvertTo-HTML
        $HeadersReplacement = [ordered] @{ '\*' = ''; }
        if (-not $ReplaceHeaders) {
            $ReplaceHeaders = [ordered] @{ }
        }
        foreach ($Key in $HeadersReplacement.Keys) {
            $ReplaceHeaders["$Key"] = $HeadersReplacement.$Key
        }
    }
    Process {
        if ($Engine -eq 'AngleSharp' -and -not $ReverseTable) {
            ConvertFrom-HTMLTableAngle -Url $Url -Content $Content -ReplaceHeaders $ReplaceHeaders -ReplaceContent $ReplaceContent
        } else {
            ConvertFrom-HTMLTableAgilityPack -Url $url -Content $Content -ReplaceHeaders $ReplaceHeaders -ReplaceContent $ReplaceContent -ReverseTable:$ReverseTable
        }
    }
    End { }
}
function Format-CSS {
    [CmdletBinding()]
    param(
        [string] $File,
        [string] $OutputFile,
        [string] $Content
    )
    # Load from file or text
    if ($File) {
        if (Test-Path -LiteralPath $File) {
            $Content = [IO.File]::ReadAllText($File)
        } else {
            Write-Warning "Format-CSS - File doesn't exists"
            return
        }
    } elseif ($Content) {

    } else {
        Write-Warning 'Format-CSS - No choice file or Content. Termninated.'
        return
    }

    $Output = Format-InternalCSS -Content $Content
    #$Content = "<style>$Content</style>"
    #$Output = Format-InternalFormatWithUglify -Content $Content -IsFragment

    # Output to file or to text
    if ($OutputFile) {
        [IO.File]::WriteAllText($OutputFile, $Output)
    } else {
        $Output
    }
}
function Format-HTML {
    [CmdletBinding()]
    param(
        [string] $File,
        [string] $OutputFile,
        [string] $Content,
        [string] $Indent = '    ',
        [NUglify.BlockStart] $BlockStartLine = [NUglify.BlockStart]::SameLine,
        [switch] $RemoveHTMLComments,
        [switch] $RemoveOptionalTags,
        [switch] $OutputTextNodesOnNewLine,
        [switch] $RemoveEmptyAttributes,
        [switch] $AlphabeticallyOrderAttributes,
        [switch] $RemoveEmptyBlocks
    )

    # Load from file or text
    if ($File) {
        if (Test-Path -LiteralPath $File) {
            $Content = [IO.File]::ReadAllText($File)
        } else {
            Write-Warning "Format-HTML - File doesn't exists"
            return
        }
    } elseif ($Content) {

    } else {
        Write-Warning 'Format-HTML - No choice file or Content. Termninated.'
        return
    }

    # Do the magic
    $formatInternalFormatWithUglifySplat = @{
        Content                       = $Content
        Indent                        = $Indent
        BlockStartLine                = $BlockStartLine
        OutputTextNodesOnNewLine      = $OutputTextNodesOnNewLine
        RemoveOptionalTags            = $RemoveOptionalTags
        RemoveEmptyAttributes         = $RemoveEmptyAttributes
        AlphabeticallyOrderAttributes = $AlphabeticallyOrderAttributes
        RemoveEmptyBlocks             = $RemoveEmptyBlocks
        RemoveComments                = $RemoveHTMLComments
        #IsFragment                    = $true
    }
    $Output = Format-InternalFormatWithUglify @formatInternalFormatWithUglifySplat

    # Output to file or to text
    if ($OutputFile) {
        [IO.File]::WriteAllText($OutputFile, $Output)
    } else {
        $Output
    }
}
function Format-JavaScript {
    [alias('Format-JS')]
    [CmdletBinding()]
    param(
        [string] $File,
        [string] $OutputFile,
        [alias('FileContent')][string] $Content
    )
    # Load from file or text
    if ($File) {
        if (Test-Path -LiteralPath $File) {
            $Content = [IO.File]::ReadAllText($File)
        } else {
            Write-Warning "Format-JavaScript - File doesn't exists"
            return
        }
    } elseif ($Content) {

    } else {
        Write-Warning 'Format-JavaScript - No choice file or Content. Termninated.'
        return
    }

    # For now don't want to give this as an option
    [int] $IndentSize = 4
    [string] $IndentChar = ' '
    [bool] $IndentWithTabs = $false
    [bool] $PreserveNewlines = $true
    [double] $MaxPreserveNewlines = 10.0
    [bool] $JslintHappy = $false
    [Jsbeautifier.BraceStyle] $BraceStyle = [Jsbeautifier.BraceStyle]::Collapse
    [bool] $KeepArrayIndentation = $false
    [bool] $KeepFunctionIndentation = $false
    [bool] $EvalCode = $false
    #[int] $WrapLineLength = 0
    [bool] $BreakChainedMethods = $false

    # do the magic
    $SplatJS = @{
        IndentSize              = $IndentSize
        IndentChar              = $IndentChar
        IndentWithTabs          = $IndentWithTabs
        PreserveNewlines        = $PreserveNewlines
        MaxPreserveNewlines     = $MaxPreserveNewlines
        JslintHappy             = $JslintHappy
        BraceStyle              = $BraceStyle
        KeepArrayIndentation    = $KeepArrayIndentation
        KeepFunctionIndentation = $KeepFunctionIndentation
        EvalCode                = $EvalCode
        #WrapLineLength          = $WrapLineLength
        BreakChainedMethods     = $BreakChainedMethods
    }

    $Output = Format-InternalJS -Content $Content @SplatJS
    #$Output = Format-InternalUglifyJS -Content $Content
    if ($OutputFile) {
        [IO.File]::WriteAllText($OutputFile, $Output)
    } else {
        $Output
    }

    <#
    $IndentLenght = $Indent.Length
    $Content = "<script>$Content</script>"
    $Output = Format-InternalFormatWithUglify -Content $Content -IsFragment
    $SplitOutput = ($Output.Split("`n"))
    $NewOutput = for ($i = 1; $i -lt $SplitOutput.Count - 1; $i++) {
        $SplitOutput[$i].SubString($IndentLenght)
    }
    $FinalOutput = $NewOutput -join "`n"
    # Output to file or to text
    if ($OutputFile) {
        [IO.File]::WriteAllText($OutputFile, $FinalOutput)
    } else {
        $FinalOutput
    }
    #>
}
function Optimize-CSS {
    [CmdletBinding()]
    param(
        [string] $File,
        [string] $OutputFile,
        [string] $Content
    )
    # Load from file or text
    if ($File) {
        if (Test-Path -LiteralPath $File) {
            $Content = [IO.File]::ReadAllText($File)
        } else {
            Write-Warning "Optimize-CSS - File doesn't exists"
            return
        }
    } elseif ($Content) {

    } else {
        Write-Warning 'Optimize-CSS - No choice file or Content. Termninated.'
        return
    }

    # Do magic
    #$Output = Optimize-InternalCSS -Content $Content
    $Output = Optimize-InternalUglifyCSS -Content $Content

    # Output to file or to text
    if ($OutputFile) {
        [IO.File]::WriteAllText($OutputFile, $Output)
    } else {
        $Output
    }
}
function Optimize-HTML {
    [CmdletBinding()]
    param(
        [string] $File,
        [string] $OutputFile,
        [string] $Content,
        [switch] $CSSDecodeEscapes
    )
    # Load from file or text
    if ($File) {
        if (Test-Path -LiteralPath $File) {
            $Content = [IO.File]::ReadAllText($File)
        } else {
            Write-Warning "Optimize-HTML - File doesn't exists"
            return
        }
    } elseif ($Content) {

    } else {
        Write-Warning 'Optimize-HTML - No choice file or Content. Termninated.'
        return
    }

    # Do magic
    $Output = Optimize-InternalUglifyHTML -Content $Content -CSSDecodeEscapes:$CSSDecodeEscapes

    # Output to file or to text
    if ($OutputFile) {
        [IO.File]::WriteAllText($OutputFile, $Output)
    } else {
        $Output
    }
}
function Optimize-JavaScript {
    [CmdletBinding()]
    param(
        [string] $File,
        [string] $OutputFile,
        [string] $Content
    )
    # Load from file or text
    if ($File) {
        if (Test-Path -LiteralPath $File) {
            $Content = [IO.File]::ReadAllText($File)
        } else {
            Write-Warning "Optimize-JavaScript - File doesn't exists"
            return
        }
    } elseif ($Content) {

    } else {
        Write-Warning 'Optimize-JavaScript - No choice file or Content. Termninated.'
        return
    }
    $Output = Optimize-InternalUglifyJS -Content $Content

    # Output to file or to text
    if ($OutputFile) {
        [IO.File]::WriteAllText($OutputFile, $Output)
    } else {
        $Output
    }
}


if ($PSVersionTable.PSEdition -eq 'Desktop' -and (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -lt 461808) { Write-Warning "This module requires .NET Framework 4.7.2 or later."; return } 


# Export functions and aliases as required
Export-ModuleMember -Function @('ConvertFrom-HTML', 'ConvertFrom-HTMLAttributes', 'ConvertFrom-HtmlTable', 'Convert-HTMLToText', 'Format-CSS', 'Format-HTML', 'Format-JavaScript', 'Optimize-CSS', 'Optimize-HTML', 'Optimize-JavaScript') -Alias @('ConvertFrom-HTMLClass', 'ConvertFrom-HTMLTag', 'Format-JS')
# SIG # Begin signature block
# MIInPgYJKoZIhvcNAQcCoIInLzCCJysCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD/rsAkh2ZbvgOh
# 9Z0acakuK4E7ElSKfySR3VW0Kyp6OaCCITcwggO3MIICn6ADAgECAhAM5+DlF9hG
# /o/lYPwb8DA5MA0GCSqGSIb3DQEBBQUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0wNjExMTAwMDAwMDBa
# Fw0zMTExMTAwMDAwMDBaMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lD
# ZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAK0OFc7kQ4BcsYfzt2D5cRKlrtwmlIiq9M71IDkoWGAM+IDaqRWVMmE8
# tbEohIqK3J8KDIMXeo+QrIrneVNcMYQq9g+YMjZ2zN7dPKii72r7IfJSYd+fINcf
# 4rHZ/hhk0hJbX/lYGDW8R82hNvlrf9SwOD7BG8OMM9nYLxj+KA+zp4PWw25EwGE1
# lhb+WZyLdm3X8aJLDSv/C3LanmDQjpA1xnhVhyChz+VtCshJfDGYM2wi6YfQMlqi
# uhOCEe05F52ZOnKh5vqk2dUXMXWuhX0irj8BRob2KHnIsdrkVxfEfhwOsLSSplaz
# vbKX7aqn8LfFqD+VFtD/oZbrCF8Yd08CAwEAAaNjMGEwDgYDVR0PAQH/BAQDAgGG
# MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFEXroq/0ksuCMS1Ri6enIZ3zbcgP
# MB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3DQEBBQUA
# A4IBAQCiDrzf4u3w43JzemSUv/dyZtgy5EJ1Yq6H6/LV2d5Ws5/MzhQouQ2XYFwS
# TFjk0z2DSUVYlzVpGqhH6lbGeasS2GeBhN9/CTyU5rgmLCC9PbMoifdf/yLil4Qf
# 6WXvh+DfwWdJs13rsgkq6ybteL59PyvztyY1bV+JAbZJW58BBZurPSXBzLZ/wvFv
# hsb6ZGjrgS2U60K3+owe3WLxvlBnt2y98/Efaww2BxZ/N3ypW2168RJGYIPXJwS+
# S86XvsNnKmgR34DnDDNmvxMNFG7zfx9jEB76jRslbWyPpbdhAbHSoyahEHGdreLD
# +cOZUbcrBwjOLuZQsqf6CkUvovDyMIIFMDCCBBigAwIBAgIQBAkYG1/Vu2Z1U0O1
# b5VQCDANBgkqhkiG9w0BAQsFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGln
# aUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtE
# aWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMTMxMDIyMTIwMDAwWhcNMjgx
# MDIyMTIwMDAwWjByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5j
# MRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBT
# SEEyIEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEA+NOzHH8OEa9ndwfTCzFJGc/Q+0WZsTrbRPV/5aid2zLX
# cep2nQUut4/6kkPApfmJ1DcZ17aq8JyGpdglrA55KDp+6dFn08b7KSfH03sjlOSR
# I5aQd4L5oYQjZhJUM1B0sSgmuyRpwsJS8hRniolF1C2ho+mILCCVrhxKhwjfDPXi
# TWAYvqrEsq5wMWYzcT6scKKrzn/pfMuSoeU7MRzP6vIK5Fe7SrXpdOYr/mzLfnQ5
# Ng2Q7+S1TqSp6moKq4TzrGdOtcT3jNEgJSPrCGQ+UpbB8g8S9MWOD8Gi6CxR93O8
# vYWxYoNzQYIH5DiLanMg0A9kczyen6Yzqf0Z3yWT0QIDAQABo4IBzTCCAckwEgYD
# VR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5k
# aWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4
# oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJv
# b3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dEFzc3VyZWRJRFJvb3RDQS5jcmwwTwYDVR0gBEgwRjA4BgpghkgBhv1sAAIEMCow
# KAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCgYIYIZI
# AYb9bAMwHQYDVR0OBBYEFFrEuXsqCqOl6nEDwGD5LfZldQ5YMB8GA1UdIwQYMBaA
# FEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3DQEBCwUAA4IBAQA+7A1aJLPz
# ItEVyCx8JSl2qB1dHC06GsTvMGHXfgtg/cM9D8Svi/3vKt8gVTew4fbRknUPUbRu
# pY5a4l4kgU4QpO4/cY5jDhNLrddfRHnzNhQGivecRk5c/5CxGwcOkRX7uq+1UcKN
# JK4kxscnKqEpKBo6cSgCPC6Ro8AlEeKcFEehemhor5unXCBc2XGxDI+7qPjFEmif
# z0DLQESlE/DmZAwlCEIysjaKJAL+L3J+HNdJRZboWR3p+nRka7LrZkPas7CM1ekN
# 3fYBIM6ZMWM9CBoYs4GbT8aTEAb8B4H6i9r5gkn3Ym6hU/oSlBiFLpKR6mhsRDKy
# ZqHnGKSaZFHvMIIFPTCCBCWgAwIBAgIQBNXcH0jqydhSALrNmpsqpzANBgkqhkiG
# 9w0BAQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEy
# IEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTIwMDYyNjAwMDAwMFoXDTIz
# MDcwNzEyMDAwMFowejELMAkGA1UEBhMCUEwxEjAQBgNVBAgMCcWabMSFc2tpZTER
# MA8GA1UEBxMIS2F0b3dpY2UxITAfBgNVBAoMGFByemVteXPFgmF3IEvFgnlzIEVW
# T1RFQzEhMB8GA1UEAwwYUHJ6ZW15c8WCYXcgS8WCeXMgRVZPVEVDMIIBIjANBgkq
# hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAv7KB3iyBrhkLUbbFe9qxhKKPBYqDBqln
# r3AtpZplkiVjpi9dMZCchSeT5ODsShPuZCIxJp5I86uf8ibo3vi2S9F9AlfFjVye
# 3dTz/9TmCuGH8JQt13ozf9niHecwKrstDVhVprgxi5v0XxY51c7zgMA2g1Ub+3ti
# i0vi/OpmKXdL2keNqJ2neQ5cYly/GsI8CREUEq9SZijbdA8VrRF3SoDdsWGf3tZZ
# zO6nWn3TLYKQ5/bw5U445u/V80QSoykszHRivTj+H4s8ABiforhi0i76beA6Ea41
# zcH4zJuAp48B4UhjgRDNuq8IzLWK4dlvqrqCBHKqsnrF6BmBrv+BXQIDAQABo4IB
# xTCCAcEwHwYDVR0jBBgwFoAUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0OBBYE
# FBixNSfoHFAgJk4JkDQLFLRNlJRmMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAK
# BggrBgEFBQcDAzB3BgNVHR8EcDBuMDWgM6Axhi9odHRwOi8vY3JsMy5kaWdpY2Vy
# dC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDA1oDOgMYYvaHR0cDovL2NybDQu
# ZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwTAYDVR0gBEUwQzA3
# BglghkgBhv1sAwEwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQu
# Y29tL0NQUzAIBgZngQwBBAEwgYQGCCsGAQUFBwEBBHgwdjAkBggrBgEFBQcwAYYY
# aHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsGAQUFBzAChkJodHRwOi8vY2Fj
# ZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEyQXNzdXJlZElEQ29kZVNpZ25p
# bmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAQEAmr1sz4ls
# LARi4wG1eg0B8fVJFowtect7SnJUrp6XRnUG0/GI1wXiLIeow1UPiI6uDMsRXPHU
# F/+xjJw8SfIbwava2eXu7UoZKNh6dfgshcJmo0QNAJ5PIyy02/3fXjbUREHINrTC
# vPVbPmV6kx4Kpd7KJrCo7ED18H/XTqWJHXa8va3MYLrbJetXpaEPpb6zk+l8Rj9y
# G4jBVRhenUBUUj3CLaWDSBpOA/+sx8/XB9W9opYfYGb+1TmbCkhUg7TB3gD6o6ES
# Jre+fcnZnPVAPESmstwsT17caZ0bn7zETKlNHbc1q+Em9kyBjaQRcEQoQQNpezQu
# g9ufqExx6lHYDjCCBY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZI
# hvcNAQEMBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZ
# MBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNz
# dXJlZCBJRCBSb290IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVow
# YjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290
# IEc0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjww
# IjBpM+zCpyUuySE98orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J5
# 8soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMH
# hOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6
# Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQ
# ecN4x7axxLVqGDgDEI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4b
# A3VdeGbZOjFEmjNAvwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9
# WV1CdoeJl2l6SPDgohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCU
# tNJhbesz2cXfSwQAzH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvo
# ZKYz0YkH4b235kOkGLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/J
# vNNBERJb5RBQ6zHFynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCP
# orF+CiaZ9eRpL5gdLfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMB
# Af8wHQYDVR0OBBYEFOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXr
# oq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRt
# MGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEF
# BQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJl
# ZElEUm9vdENBLmNydDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgw
# BgYEVR0gADANBgkqhkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cH
# vZqsoYcs7IVeqRq7IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8
# UgPITtAq3votVs/59PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTn
# f+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxU
# jG/voVA9/HYJaISfb8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8j
# LfR+cWojayL/ErhULSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDCCBq4w
# ggSWoAMCAQICEAc2N7ckVHzYR6z9KGYqXlswDQYJKoZIhvcNAQELBQAwYjELMAkG
# A1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRp
# Z2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MB4X
# DTIyMDMyMzAwMDAwMFoXDTM3MDMyMjIzNTk1OVowYzELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVk
# IEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTCCAiIwDQYJKoZIhvcN
# AQEBBQADggIPADCCAgoCggIBAMaGNQZJs8E9cklRVcclA8TykTepl1Gh1tKD0Z5M
# om2gsMyD+Vr2EaFEFUJfpIjzaPp985yJC3+dH54PMx9QEwsmc5Zt+FeoAn39Q7SE
# 2hHxc7Gz7iuAhIoiGN/r2j3EF3+rGSs+QtxnjupRPfDWVtTnKC3r07G1decfBmWN
# lCnT2exp39mQh0YAe9tEQYncfGpXevA3eZ9drMvohGS0UvJ2R/dhgxndX7RUCyFo
# bjchu0CsX7LeSn3O9TkSZ+8OpWNs5KbFHc02DVzV5huowWR0QKfAcsW6Th+xtVhN
# ef7Xj3OTrCw54qVI1vCwMROpVymWJy71h6aPTnYVVSZwmCZ/oBpHIEPjQ2OAe3Vu
# JyWQmDo4EbP29p7mO1vsgd4iFNmCKseSv6De4z6ic/rnH1pslPJSlRErWHRAKKtz
# Q87fSqEcazjFKfPKqpZzQmiftkaznTqj1QPgv/CiPMpC3BhIfxQ0z9JMq++bPf4O
# uGQq+nUoJEHtQr8FnGZJUlD0UfM2SU2LINIsVzV5K6jzRWC8I41Y99xh3pP+OcD5
# sjClTNfpmEpYPtMDiP6zj9NeS3YSUZPJjAw7W4oiqMEmCPkUEBIDfV8ju2TjY+Cm
# 4T72wnSyPx4JduyrXUZ14mCjWAkBKAAOhFTuzuldyF4wEr1GnrXTdrnSDmuZDNIz
# tM2xAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAGAQH/AgEAMB0GA1UdDgQWBBS6
# FtltTYUvcyl2mi91jGogj57IbzAfBgNVHSMEGDAWgBTs1+OC0nFdZEzfLmc/57qY
# rhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgwdwYIKwYB
# BQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20w
# QQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDowOKA2oDSGMmh0dHA6Ly9jcmwz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3JsMCAGA1UdIAQZ
# MBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAfVmO
# wJO2b5ipRCIBfmbW2CFC4bAYLhBNE88wU86/GPvHUF3iSyn7cIoNqilp/GnBzx0H
# 6T5gyNgL5Vxb122H+oQgJTQxZ822EpZvxFBMYh0MCIKoFr2pVs8Vc40BIiXOlWk/
# R3f7cnQU1/+rT4osequFzUNf7WC2qk+RZp4snuCKrOX9jLxkJodskr2dfNBwCnzv
# qLx1T7pa96kQsl3p/yhUifDVinF2ZdrM8HKjI/rAJ4JErpknG6skHibBt94q6/ae
# sXmZgaNWhqsKRcnfxI2g55j7+6adcq/Ex8HBanHZxhOACcS2n82HhyS7T6NJuXdm
# kfFynOlLAlKnN36TU6w7HQhJD5TNOXrd/yVjmScsPT9rp/Fmw0HNT7ZAmyEhQNC3
# EyTN3B14OuSereU0cZLXJmvkOHOrpgFPvT87eK1MrfvElXvtCl8zOYdBeHo46Zzh
# 3SP9HSjTx/no8Zhf+yvYfvJGnXUsHicsJttvFXseGYs2uJPU5vIXmVnKcPA3v5gA
# 3yAWTyf7YGcWoWa63VXAOimGsJigK+2VQbc61RWYMbRiCQ8KvYHZE/6/pNHzV9m8
# BPqC3jLfBInwAM1dwvnQI38AC+R2AibZ8GV2QqYphwlHK+Z/GqSFD/yYlvZVVCsf
# gPrA8g4r5db7qS9EFUrnEw4d2zc4GqEr9u3WfPwwggbAMIIEqKADAgECAhAMTWly
# S5T6PCpKPSkHgD1aMA0GCSqGSIb3DQEBCwUAMGMxCzAJBgNVBAYTAlVTMRcwFQYD
# VQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgVHJ1c3RlZCBH
# NCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwHhcNMjIwOTIxMDAwMDAw
# WhcNMzMxMTIxMjM1OTU5WjBGMQswCQYDVQQGEwJVUzERMA8GA1UEChMIRGlnaUNl
# cnQxJDAiBgNVBAMTG0RpZ2lDZXJ0IFRpbWVzdGFtcCAyMDIyIC0gMjCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBAM/spSY6xqnya7uNwQ2a26HoFIV0Mxom
# rNAcVR4eNm28klUMYfSdCXc9FZYIL2tkpP0GgxbXkZI4HDEClvtysZc6Va8z7GGK
# 6aYo25BjXL2JU+A6LYyHQq4mpOS7eHi5ehbhVsbAumRTuyoW51BIu4hpDIjG8b7g
# L307scpTjUCDHufLckkoHkyAHoVW54Xt8mG8qjoHffarbuVm3eJc9S/tjdRNlYRo
# 44DLannR0hCRRinrPibytIzNTLlmyLuqUDgN5YyUXRlav/V7QG5vFqianJVHhoV5
# PgxeZowaCiS+nKrSnLb3T254xCg/oxwPUAY3ugjZNaa1Htp4WB056PhMkRCWfk3h
# 3cKtpX74LRsf7CtGGKMZ9jn39cFPcS6JAxGiS7uYv/pP5Hs27wZE5FX/NurlfDHn
# 88JSxOYWe1p+pSVz28BqmSEtY+VZ9U0vkB8nt9KrFOU4ZodRCGv7U0M50GT6Vs/g
# 9ArmFG1keLuY/ZTDcyHzL8IuINeBrNPxB9ThvdldS24xlCmL5kGkZZTAWOXlLimQ
# prdhZPrZIGwYUWC6poEPCSVT8b876asHDmoHOWIZydaFfxPZjXnPYsXs4Xu5zGcT
# B5rBeO3GiMiwbjJ5xwtZg43G7vUsfHuOy2SJ8bHEuOdTXl9V0n0ZKVkDTvpd6kVz
# HIR+187i1Dp3AgMBAAGjggGLMIIBhzAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/
# BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAgBgNVHSAEGTAXMAgGBmeBDAEE
# AjALBglghkgBhv1sBwEwHwYDVR0jBBgwFoAUuhbZbU2FL3MpdpovdYxqII+eyG8w
# HQYDVR0OBBYEFGKK3tBh/I8xFO2XC809KpQU31KcMFoGA1UdHwRTMFEwT6BNoEuG
# SWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJTQTQw
# OTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcmwwgZAGCCsGAQUFBwEBBIGDMIGAMCQG
# CCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wWAYIKwYBBQUHMAKG
# TGh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFJT
# QTQwOTZTSEEyNTZUaW1lU3RhbXBpbmdDQS5jcnQwDQYJKoZIhvcNAQELBQADggIB
# AFWqKhrzRvN4Vzcw/HXjT9aFI/H8+ZU5myXm93KKmMN31GT8Ffs2wklRLHiIY1UJ
# RjkA/GnUypsp+6M/wMkAmxMdsJiJ3HjyzXyFzVOdr2LiYWajFCpFh0qYQitQ/Bu1
# nggwCfrkLdcJiXn5CeaIzn0buGqim8FTYAnoo7id160fHLjsmEHw9g6A++T/350Q
# p+sAul9Kjxo6UrTqvwlJFTU2WZoPVNKyG39+XgmtdlSKdG3K0gVnK3br/5iyJpU4
# GYhEFOUKWaJr5yI+RCHSPxzAm+18SLLYkgyRTzxmlK9dAlPrnuKe5NMfhgFknADC
# 6Vp0dQ094XmIvxwBl8kZI4DXNlpflhaxYwzGRkA7zl011Fk+Q5oYrsPJy8P7mxNf
# arXH4PMFw1nfJ2Ir3kHJU7n/NBBn9iYymHv+XEKUgZSCnawKi8ZLFUrTmJBFYDOA
# 4CPe+AOk9kVH5c64A0JH6EE2cXet/aLol3ROLtoeHYxayB6a1cLwxiKoT5u92Bya
# UcQvmvZfpyeXupYuhVfAYOd4Vn9q78KVmksRAsiCnMkaBXy6cbVOepls9Oie1FqY
# yJ+/jbsYXEP10Cro4mLueATbvdH7WwqocH7wl4R44wgDXUcsY6glOJcB0j862uXl
# 9uab3H4szP8XTE0AotjWAQ64i+7m4HJViSwnGWH2dwGMMYIFXTCCBVkCAQEwgYYw
# cjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVk
# IElEIENvZGUgU2lnbmluZyBDQQIQBNXcH0jqydhSALrNmpsqpzANBglghkgBZQME
# AgEFAKCBhDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqG
# SIb3DQEJBDEiBCCNYVnxr/9itdJ2prRKjQl8MCTbSYc08kZdysIviusAADANBgkq
# hkiG9w0BAQEFAASCAQAv+qyMdKK9tfWPFra0mY0rgJ4hwDGu1o8VUKC6TKafNZIS
# yoW7XKQ6K41oInUc9oz6dRyASC1yM3EwUtF3RS9sFtzTqHjUveNQSAGq1aLX8rbD
# mXA38vGlHvPm8QchUkwD4WpqZpS78OQbw/hWAKCJ/FMVTf6fSoCjX+pMNcxlXxFI
# iW+YK68mcLp5v8nkhDwcpAx7d/BVPwASgIHzOBA9Os3Wv246Gf1XfPsFPgAI43yp
# KCrbmqTOqBS6diz2uf4SFI+e9sAX57/0aqH1upJ2VK4gJ5fNAlJjpTAEojoHNhA5
# G41o09nQvCRkxSEGzCW2jJbZfoqqzzt2ir2Z/8c1oYIDIDCCAxwGCSqGSIb3DQEJ
# BjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0
# LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQwOTYgU0hB
# MjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwqSj0pB4A9WjANBglghkgBZQME
# AgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8X
# DTIzMDExNTE4MzAyN1owLwYJKoZIhvcNAQkEMSIEIPQKCyg9W3w1ndaaYumgih3D
# KlCKDhFF1bH/2DmiyCCpMA0GCSqGSIb3DQEBAQUABIICAIDRzyOzOU9Bg9TSS/8H
# zZEjUvIm7bHxuxTFExfwjw077JoqcnC+bdSUDJYzuPthvSzA0P4WX7ErDmL6v4V1
# 8pL8s+RFA14oZFfDw4j/yQnoBr9jL1KwhXK5L6g0BFRBdixlOOfFwMhY5dTI7nv1
# /DwooWIKWNjSolzwrkz0O/nY5IffmKK3cR2/K/iqGu2X/70HQQRxRQznbnFpvdcd
# XWn4PQyzMpZezK2Oz/SM4QpMAP5CffCmS05080707TSo79QTWfxkQ0KlmO/EzZ2y
# 0Eg3msKzyLY+JgPGqKQa+jFMDfTv6Jb93PGgYOsxDDE+Y7SlfIkO7ka6Aoq36SoB
# hnicjSp4tKqMzAMm3WCGLzxgni0a43PNWSJ2vVbSbAGgXrmmBzAEoUbuRoYcoetB
# InLDMiMufg2DsowxsAKyTLe3BwciKjbblhcYYhKPXeWf5ldFIrjkryhQYjXdgU3T
# i8+luWDeYw2WmKBqfUKWuJxUKnqGqB8/un4qsnQXvKdJ2okBg99fwIjpjDNne7ye
# mYzthnfLleJuu70dWYpruBAeuRb+LEg/Vo60UZLogiu3G02+Aftqm4+Nk7j1phK+
# HWnlbt3Gajol8v63fsnguJp7jArMsg0zZJQhQK+AgsnDFILFWvuPyDEbqc6183mS
# U+2eEbcTda9aQt99kC4yWwxy
# SIG # End signature block
