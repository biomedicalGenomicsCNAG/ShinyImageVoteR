import React, { useState, ChangeEvent } from "react";
import { 
    AppBar, 
    Tabs, 
    Tab, 
    Typography, 
    Container, 
    RadioGroup, 
    FormControlLabel, 
    Radio, 
    Checkbox, 
    TextField, 
    Button, 
    Box 
} from "@mui/material";
import { useQuery, UseQueryResult } from "@tanstack/react-query";
import axios from "axios";

const fetchImageUrl = async (): Promise<string> => {
  const response = await axios.get(
    "http://localhost:3000/api/images/next"
  );
  console.log("response", response);
  return response.data.url;
};

const Voting: React.FC = () => {
  const [tabIndex, setTabIndex] = useState<number>(0);
  const [agreement, setAgreement] = useState<string>("yes");
  const [observations, setObservations] = useState<string[]>([]);
  const [comment, setComment] = useState<string>("");

  const { 
    data: imageUrl, 
    isLoading, 
    error 
  }: UseQueryResult<string, Error> = useQuery(
    { 
      queryKey: ["variantImage"], 
      queryFn: fetchImageUrl 
    }
  );

  const handleTabChange = (event: React.SyntheticEvent, newValue: number) => {
    console.log("newValue", newValue);
    console.log("event", event);
    setTabIndex(newValue);
  };

  const handleAgreementChange = (event: ChangeEvent<HTMLInputElement>) => {
    setAgreement(event.target.value);
  };

  const handleObservationChange = (event: ChangeEvent<HTMLInputElement>) => {
    const value = event.target.value;
    setObservations((prev) =>
      prev.includes(value) ? prev.filter((obs) => obs !== value) : [...prev, value]
    );
  };

  return (
    <Container>
      <AppBar position="static">
        <Tabs value={tabIndex} onChange={handleTabChange} indicatorColor="secondary" textColor="inherit">
          <Tab label="Vote" />
          <Tab label="Monitor" />
        </Tabs>
      </AppBar>

      {tabIndex === 0 && (
        <Box>
          <Typography variant="h6">Logged in as Training (answers won't be saved)</Typography>
          <Typography variant="h5">chr21:38376386</Typography>
          {/* <img
            src=""
            alt="Variant"
            height={500}
            width={888}
          /> */}
          {isLoading ? (
            <Typography>Loading image...</Typography>
          ) : error ? (
            <Typography color="error">Error loading image</Typography>
          ) : (
            <>
            <span>Image loaded</span>
            <span>{imageUrl}</span>
            <img src={imageUrl} alt="Variant" height={500} width={888} />
            </>
          )}
          <Typography variant="h5">
            Variant: <span style={{ color: "#FF7F00" }}>G</span> &gt; <span style={{ color: "#33A02C" }}>A</span>
          </Typography>

          <RadioGroup value={agreement} onChange={handleAgreementChange}>
            <FormControlLabel value="yes" control={<Radio />} label="Yes, it is." />
            <FormControlLabel value="no" control={<Radio />} label="There is no variant." />
            <FormControlLabel value="diff_var" control={<Radio />} label="There is a different variant." />
            <FormControlLabel value="not_confident" control={<Radio />} label="I'm not sure." />
          </RadioGroup>

          {(agreement === "not_confident" || agreement === "diff_var") && (
            <Box>
              <Typography variant="h6">Observations</Typography>
              <FormControlLabel
                control={<Checkbox checked={observations.includes("coverage")} onChange={handleObservationChange} value="coverage" />}
                label="Issues with coverage"
              />
              <FormControlLabel
                control={<Checkbox checked={observations.includes("low_vaf")} onChange={handleObservationChange} value="low_vaf" />}
                label="Low allele frequency"
              />
              <FormControlLabel
                control={<Checkbox checked={observations.includes("alignment")} onChange={handleObservationChange} value="alignment" />}
                label="Alignment issues"
              />
              <FormControlLabel
                control={<Checkbox checked={observations.includes("complex")} onChange={handleObservationChange} value="complex" />}
                label="Complex event"
              />
              <FormControlLabel
                control={<Checkbox checked={observations.includes("img_qual_issue")} onChange={handleObservationChange} value="img_qual_issue" />}
                label="Quality issues with the image"
              />
              <FormControlLabel
                control={<Checkbox checked={observations.includes("platform_issue")} onChange={handleObservationChange} value="platform_issue" />}
                label="Issue with the voting platform"
              />

              <TextField label="Comments" fullWidth value={comment} onChange={(e) => setComment(e.target.value)} />
            </Box>
          )}
          <Button variant="contained" color="primary">Next</Button>
        </Box>
      )}

      {tabIndex === 1 && (
        <Box>
          <Typography variant="h5">Total screenshots: 75</Typography>
          <Typography variant="h6">*10 training questions are subtracted from the number of votes.</Typography>
          <Button variant="contained" color="secondary">Refresh counts</Button>
        </Box>
      )}
    </Container>
  );
};

export default Voting;
