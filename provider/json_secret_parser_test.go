package provider

import (
        "testing"
	"fmt"
)

func TestNotValidJson(t *testing.T) {

	jsonNotValid := "NotValidJson"
        descriptor := SecretDescriptor{ObjectName:  jsonNotValid}

	notValidSecretValue := SecretValue{
		Value: []byte(jsonNotValid),
		Descriptor: descriptor,
	}

	jsonSecretParser := JsonSecretParser {secretValue: notValidSecretValue}

	jsmePath := []JSMEPathEntry {
	   JSMEPathEntry {
		Path: ".username",
		ObjectAlias: "test",

	   },
	}

	expectedErrorMessage := fmt.Sprintf("Secret with object name: %s does not have parsable JSON content", jsonNotValid)
	_, err := jsonSecretParser.getJsonSecrets(jsmePath)

	if err == nil || err.Error() != expectedErrorMessage {
		t.Fatalf("Expected error: %s, got error: %v", expectedErrorMessage, err)
	}
}

