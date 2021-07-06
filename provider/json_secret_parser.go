package provider

import (
	"github.com/savaki/jq"
	"encoding/json"
	"fmt"
)

//Wrapper around SecretValue to parse out individual JSON json key pairs from secret
type JsonSecretParser struct {
	secretValue SecretValue
}

//parse out and return specified key value pairs from the secret 
func (j *JsonSecretParser) getJsonSecrets(jsmePathEntries []JSMEPathEntry) (s []*SecretValue, e error) {
	secretValue := j.secretValue.Value

	if !json.Valid(secretValue) {
		return nil, fmt.Errorf("Secret with object name: %s does not have parsable JSON content", j.secretValue.Descriptor.ObjectName)
	}
	var jsonValues []*SecretValue

	//fetch all specified key value pairs`
	for _, jsmePathEntry  := range jsmePathEntries {
		op, _ := jq.Parse(jsmePathEntry.Path)

		jsonSecret, err := op.Apply(secretValue)
		
		//trim off surrounding quotes
		jsonSecret = jsonSecret[1:len(jsonSecret)-1]
		if err != nil {
			return nil, fmt.Errorf("JSME Path - %s for object alias - %s does not point to a valid objet",
				jsmePathEntry.Path, jsmePathEntry.ObjectAlias)
		}

		descriptor := SecretDescriptor{
			ObjectAlias: jsmePathEntry.ObjectAlias,
			ObjectType: j.secretValue.Descriptor.ObjectType,
		}
		secretValue := SecretValue{
			Value: jsonSecret,
			Descriptor: descriptor,
		}
		jsonValues = append(jsonValues, &secretValue)

	}
	return jsonValues, nil
}

