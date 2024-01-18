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

Export-ModuleMember -Function Search-InBrowser, SearchDDG-Inline, AskGemini-Single