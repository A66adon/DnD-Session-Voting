package ds.dnd.voting.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class VoteRequestDTO {
    private List<Long> timeSlotIds;
    private Long preferredTimeSlotId;
}

