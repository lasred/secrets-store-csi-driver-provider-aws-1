package provider

import (
	"k8s.io/klog/v2"
        "github.com/savaki/jq"

)

//Wrapper around SecretValue to parse out individual json fields from secret
type JsonSecretParser struct {
	secretValue SecretValue
}

//parse out and return individual jey pair values as SecretValue
func (j *JsonSecretParser) getJsonSecrets(jsmePathObjects []JSMEPathObject) (s []*SecretValue, e error) {
	var jsonValues []*SecretValue
	//fetch all specified key value apris 
	for _, jsmePathObject  := range jsmePathObjects {
		op, _ := jq.Parse(jsmePathObject.Path)
		
		secretValueString := string(j.secretValue.Value)
		klog.Info("json parser processing seecret " + secretValueString)
		jsonSecret, _ := op.Apply(j.secretValue.Value)

		jsonSecretString := string(jsonSecret)

		klog.Info("json secret string is" + jsonSecretString)

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
        for _, jsonValue := range jsonValues {
		klog.Info("the value is" + string(jsonValue.Value))
	}
	return jsonValues, nil
}

