package provider

import (
        "github.com/savaki/jq"
)

//Wrapper around SecretValue to parse out individual json key value from secret
type JsonSecretParser struct {
	secretValue SecretValue
}

//parse out and return individual jey pair values as SecretValue
func (j *JsonSecretParser) getJsonSecrets(jsmePathObjects []JSMEPathObject) (s []*SecretValue, e error) {
	var jsonValues []*SecretValue
	//fetch all specified key value apris 
	for _, jsmePathObject  := range jsmePathObjects {
		op, _ := jq.Parse(jsmePathObject.Path)

		jsonSecret, _ := op.Apply(j.secretValue.Value)

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

