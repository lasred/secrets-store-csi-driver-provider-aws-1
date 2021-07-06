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

func TestJSMEPathPointsToInvalidObject(t *testing.T) {

	jsonContent := `{"username": "ParameterStoreUser", "password": "PasswordForParameterStore"}`
        descriptor := SecretDescriptor{ObjectName: "test secret"}
	objectAlias := "test"
        path := "testpath"
        jsonSecretValue := SecretValue{
                Value: []byte(jsonContent),
                Descriptor: descriptor,
        }

        jsonSecretParser := JsonSecretParser {secretValue: jsonSecretValue}

        jsmePath := []JSMEPathEntry {
           JSMEPathEntry {
                Path: path,
                ObjectAlias: objectAlias,
           },
        }

        expectedErrorMessage := fmt.Sprintf("JSME Path - %s for object alias - %s does not point to a valid objet",path, objectAlias)
        _, err := jsonSecretParser.getJsonSecrets(jsmePath)

        if err == nil || err.Error() != expectedErrorMessage {
                t.Fatalf("Expected error: %s, got error: %v", expectedErrorMessage, err)
        }
}

