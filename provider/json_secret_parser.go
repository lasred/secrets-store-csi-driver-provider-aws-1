package provider

import (
        "github.com/savaki/jq"
	"encoding/json"
	"fmt"
)

//Wrapper around SecretValue to parse out individual json key value from secret
type JsonSecretParser struct {
	secretValue SecretValue
}

//parse out and return individual jey pair values as SecretValue
func (j *JsonSecretParser) getJsonSecrets(jsmePathObjects []JSMEPathObject) (s []*SecretValue, e error) {
	secretValue := j.secretValue.Value

	if !json.Valid(secretValue) {
		return nil, fmt.Errorf("Secret with object name: %s does not have parsable JSON content", j.secretValue.Descriptor.ObjectName)
	}
	var jsonValues []*SecretValue
	//fetch all specified key value apris 
	for _, jsmePathObject  := range jsmePathObjects {
		op, _ := jq.Parse(jsmePathObject.Path)

		jsonSecret, err := op.Apply(secretValue)

		if err != nil {
			return nil, fmt.Errorf("JSME Path - %s for object alias - %s does not point to a valid objet",
				jsmePathObject.Path, jsmePathObject.ObjectAlias)
		}

		descriptor := SecretDescriptor{
			ObjectAlias: jsmePathObject.ObjectAlias,
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

