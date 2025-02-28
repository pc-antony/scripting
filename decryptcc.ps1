function Rotate {
    param (
        [string]$EncryptedText, # text to be decrypted
        [int]$RotValue # rotation value used to encrypt the text (standard is 13)
    )
    $rotMap = @{}
    $alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $lcaseAlpha = "abcdefghijklmnopqrstuvwxyz"
    $vowelEnc = @{ "1" = "a"; "2" = "e"; "3" = "i"; "4" = "o"; "5" = "u" }
    $isAscii=$false

    for ($i = 0; $i -lt 26; $i++) {
        # create a hashtable that maps each letter to its rotated value
        $rotMap[$alpha[$i]] = $alpha[($i + $RotValue) % 26]
        # create a hashtable that maps each lowercase letter to its rotated value
        $rotMap[$lcaseAlpha[$i]] = $lcaseAlpha[($i + $RotValue) % 26]
    }
    
    $output = ""
    $asciiCode = ""
    foreach ($char in $EncryptedText.ToCharArray()) {
        if(!($isAscii)){
            if($rotMap.ContainsKey($char)) {
                # char is a letter so we just rotate it using the rotMap hashtable
                $output += $rotMap[$char]
            }elseif($vowelEnc.ContainsKey("$char")) {
                # char is a vowel so we just replace it with the corresponding value in the vowelEnc hashtable
                $output += $vowelEnc["$char"]
            }elseif($char -eq "'") {
                # char is an ascii code so we need to extract it and convert it to a character
                # we set isAscii to true to indicate that we are currently processing an ascii code
                $isAscii=$true
            }else{
                # char is a non-letter, non-vowel character so we just append it to the output
                $output += $char
            }
        }else{
            # we are currently processing an ascii code...
            if($char -eq "'"){
                # we reached the end of the ascii code so we convert it to a character and append it to the output
                $output += [char][int]$asciiCode
                $asciiCode=""
                $isAscii=$false
            }else{
                # we are still processing the ascii code so we append the current character to the asciiCode string
                $asciiCode = $asciiCode + $char
            }
        }
    }
    # return the decrypted text
    return $output
}

$encryptedText = Read-Host "Enter text string: "
$decryptedText = Rotate -EncryptedText $encryptedText -RotValue 13
Write-Output "Decrypted Text:`n===============`n$decryptedText`n"
