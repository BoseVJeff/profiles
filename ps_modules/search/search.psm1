# Most URLs taken from default Vivaldi settings unless noted otherwise

# Bing search URLs
# Search: https://www.bing.com/search?FORM=INCOH2&PC=1VIV&PTAG=ICO-c9d0fc87&q=%s
# Search autocomplete: https://www.bing.com/osjson.aspx?query=%s&language={language}
# Image search: https://www.bing.com/images/detail/search?iss=sbiupload&{bing:Referral}#enterInsights
# Image search POST params: imageBin={google:imageThumbnailBase64}

# Yahoo search URLs
# Search: https://in.search.yahoo.com/yhs/search?hspart=iry&hsimp=yhs-fullyhosted_009&type=dpp_vvldnu_00_00&param1=1&param2=pa%3Ddowncoll%26b%3DVivaldi&p=%s

# DuckDuckGo search URLs
# Search: https://start.duckduckgo.com/?q=%s&{ddg:Referral}
# Search autocomplete: https://duckduckgo.com/ac/?q=%s&type=list

# Google search URLs
# Search: {google:baseURL}search?q=%s&{google:originalQueryForSuggestion}{google:prefetchSource}{google:sourceId}{google:contextualSearchVersion}ie={inputEncoding}
# Image Search: https://www.google.com/searchbyimage/upload
# Image search POST params: encoded_image={google:imageThumbnail},image_url={google:imageURL},sbisrc={google:imageSearchSource},original_width={google:imageOriginalWidth},original_height={google:imageOriginalHeight}

# Wikipedia Search URLs
# Search: https://en.wikipedia.org/wiki/Special:Search?search=%s
# Search autocomplete: https://en.wikipedia.org/w/api.php?action=opensearch&search=%s

# Searching the internet in the browser
function Search-InBrowser {
	param (
		[String]$term
	)
	$enc_term = [uri]::EscapeUriString($term);
	vivaldi.exe "https://duckduckgo.com/?q=$enc_term";
}

# Search using the DDG API.
# API ref here: https://stackoverflow.com/a/38964931
function SearchDDG-Inline {
	param (
		[String]$term
	)
	$enc_term = [uri]::EscapeUriString($term);
	$res=Invoke-WebRequest -Uri "http://api.duckduckgo.com/?q=$enc_term&format=json"
	$json=$res | ConvertFrom-Json
	$i=1
	foreach ($data in $json.RelatedTopics) {
		if(Get-Member -inputobject $data -name "Text" -Membertype Properties) {
			Write-Host "$i. $($data.Text) --> $($data.FirstURL)"
		}
		ElseIf (Get-Member -inputobject $data -name "Name" -Membertype Properties) {
			Write-Host "$i. $($data.Name)"
			$j=1
			foreach ($topic in $data.Topics) {
				Write-Host "`t $j. $($topic.Text) --> $($topic.FirstURL)"
				$j=$j+1
			}
		}
		$i=$i+1
	}
}

function SearchDDG-Scrape {
    param (
        [String]$term
    )
    $ans=""

    # Write-Output "Encoding search term"
    $enc_term = [uri]::EscapeUriString($term);

    # Write-Output "Parsing DOM"
    $html=ConvertFrom-Html -Engine AngleSharp -Url "https://html.duckduckgo.com/html/?q=$enc_term"
    
    # Write-Output "Getting quick answer title"
    # Quick answer title
    $qtitle=$html.QuerySelector("body > div:nth-child(3) > div.zci-wrapper > div > h1 > a").Text
    # Write-Output "Getting wuick answer description"
    # Quick answer description
    # Storing this as child nodes for now as indexing into a null variable throws an exception
    $qdesc=$html.QuerySelector("#zero_click_abstract").ChildNodes
    $qlink=$html.QuerySelector("body > div:nth-child(3) > div.zci-wrapper > div > h1 > a").Href
    If($qtitle) {
        $ans+="$qtitle"
    } 
    If($qdesc) {
        # Write-Output "Parsing and trimming Quick answer description"
        $qdescalt=$html.QuerySelector("#zero_click_abstract").TextContent.Trim()
        # if($qdescalt -eq "") {
        #     $qdesc=$qdesc[1].Text.Trim()
        # }
        $qdesc=$qdescalt
        $ans+=": $qdesc"
    }
    If($qlink) {
        $ans+="`n$qlink"
    }
    # Write-Output $html.QuerySelector("body > div:nth-child(3) > div.zci-wrapper > div > h1 > a").Href
    $ans+="`n"

    for($i=1;$i -le 5;$i++) {
        # Write-Output "Selecting search result title no $i"
        $resTitle=$html.QuerySelector("#links > div:nth-child(${i}) > div > h2 > a").Text.Trim()
        # Write-Output "Selecting search result description no $i"
        $resBody=$html.QuerySelector("#links > div:nth-child(${i}) > div > a").Text.Trim()
        # Write-Output "Selecting search result link no $i"
        $resLinkRaw=[uri]($html.QuerySelector("#links > div:nth-child(${i}) > div > h2 > a").Href)
        # From https://stackoverflow.com/a/56399659
        $ParsedQueryString = [System.Web.HttpUtility]::ParseQueryString($resLinkRaw.Query)
        # The first query is the link itself for now.
        # For future reference, the param associated is `uddg`.
        $resLink=$ParsedQueryString[0]

        $ans+="`n$resTitle`n$resBody`n$resLink`n"
    }

    Write-Output $ans
}

# Ask Gemini Pro AI
function AskGemini-Single {
	param (
		[String]$term
	)
	$body="{
		'contents': [{
			'parts': [{
				'text': '$term'
			}]
		}]
	}"

	$res=Invoke-RestMethod -Uri "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$(Get-GeminiApiKey)" -Method "POST" -ContentType "application/json" -Body $body;

	Show-Markdown -InputObject $res.candidates[0].content.parts[0].text
}

Export-ModuleMember -Function Search-InBrowser, SearchDDG-Inline, AskGemini-Single, SearchDDG-Scrape